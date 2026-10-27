import AppKit
import ApplicationServices
import QuartzCore
import WebKit

// A standalone macOS player for the unmodified upstream animation.
// ChatGPT prepares behind the overlay; the last frame covers the foreground handoff.
enum BootMode: String, CaseIterable { case full, simple, off }

struct Options {
    let arguments = CommandLine.arguments
    func value(_ flag: String) -> String? {
        guard let i = arguments.firstIndex(of: flag), i + 1 < arguments.count else { return nil }
        return arguments[i + 1]
    }
    var reportPath: String? { value("--verify") }
    var testing: Bool { reportPath != nil }
    var liveHandoffTest: Bool { testing && arguments.contains("--verify-handoff") }
    var windowed: Bool { arguments.contains("--windowed") }
    var preview: Bool { arguments.contains("--preview") }
}

final class BootWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class Launcher: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    let options = Options()
    var mode = BootMode.full
    var window: NSWindow?
    var webView: WKWebView?
    var titleObservation: NSKeyValueObservation?
    var keyMonitor: Any?
    var deadline: Timer?
    var finished = false
    var startTime = Date()
    var scriptErrors: [String] = []
    var previousPresentation: NSApplication.PresentationOptions = []
    var handoff = HandoffState()
    let targetWindows = TargetWindowManager()
    var targetApp: NSRunningApplication?
    var targetError: String?
    var targetProbe: Timer?
    var probeBusy = false
    var waitDeadline: Timer?
    var activationProbe: Timer?
    var activationObserver: NSObjectProtocol?
    var screenFrame = CGRect.zero
    var desktopTop: CGFloat = 0
    var telemetry: [String: Any] = [:]
    var verificationReport: [String: Any]?

    var shouldPrepareTarget: Bool { !options.preview && (!options.testing || options.liveHandoffTest) }
    var elapsed: Double { Date().timeIntervalSince(startTime) }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        previousPresentation = NSApp.presentationOptions
        if let path = options.value("--check-window-access") {
            let result = ["accessibilityPermission": TargetWindowManager.hasPermission]
            if let data = try? JSONSerialization.data(withJSONObject: result) {
                try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
            }
            NSApp.terminate(nil)
            return
        }
        if options.arguments.contains("--request-window-access") {
            requestWindowAccess()
            NSApp.terminate(nil)
            return
        }
        mode = BootMode(rawValue: options.value("--mode") ?? UserDefaults.standard.string(forKey: "mode") ?? "full") ?? .full
        if !options.testing && NSEvent.modifierFlags.contains(.option) {
            guard chooseMode() else { NSApp.terminate(nil); return }
        }
        startTime = Date()
        let screen = NSScreen.main ?? NSScreen.screens.first
        screenFrame = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        desktopTop = NSScreen.screens.first?.frame.maxY ?? 900
        telemetry["accessibilityPermission"] = TargetWindowManager.hasPermission
        telemetry["expectedFrame"] = [screenFrame.minX, desktopTop - screenFrame.maxY, screenFrame.width, screenFrame.height]
        guard mode != .off else {
            if shouldPrepareTarget { prepareChatGPT() }
            finish("off")
            return
        }
        showAnimation()
        if shouldPrepareTarget { prepareChatGPT() }
    }

    func buildMenu() {
        let menu = NSMenu()
        let item = NSMenuItem()
        menu.addItem(item)
        let appMenu = NSMenu(title: "ChatGPT 550C")
        appMenu.addItem(withTitle: "跳过动画并打开 ChatGPT", action: #selector(skip), keyEquivalent: "w").target = self
        appMenu.addItem(withTitle: "设置窗口铺满权限…", action: #selector(requestWindowAccess), keyEquivalent: "").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出动画", action: #selector(cancel), keyEquivalent: "q").target = self
        item.submenu = appMenu
        NSApp.mainMenu = menu
    }

    func chooseMode() -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "ChatGPT 550C 动画模式"
        let permission = TargetWindowManager.hasPermission ? "已允许自动铺满 ChatGPT 窗口。" : "自动铺满窗口需在 macOS“辅助功能”中允许此启动器；未授权时仍可提前启动和渐隐切换。"
        alert.informativeText = "选择将用于以后打开的模式。\n\n\(permission)"
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 300, height: 28))
        popup.addItems(withTitles: ["完整 550C 动画", "快速模式（仅 Logo）", "直接打开 ChatGPT"])
        popup.selectItem(at: BootMode.allCases.firstIndex(of: mode) ?? 0)
        alert.accessoryView = popup
        alert.addButton(withTitle: "保存并打开")
        alert.addButton(withTitle: "取消")
        alert.addButton(withTitle: "设置窗口铺满权限")
        let response = alert.runModal()
        if response == .alertThirdButtonReturn { requestWindowAccess(); return false }
        guard response == .alertFirstButtonReturn else { return false }
        mode = BootMode.allCases[popup.indexOfSelectedItem]
        UserDefaults.standard.set(mode.rawValue, forKey: "mode")
        return true
    }

    func showAnimation() {
        guard let resources = Bundle.main.resourceURL else { finish("missing-resources"); return }
        let file = resources.appendingPathComponent("550c-overlay.html")
        guard FileManager.default.fileExists(atPath: file.path) else { finish("missing-animation"); return }
        guard let originalHTML = try? String(contentsOf: file, encoding: .utf8) else { finish("unreadable-animation"); return }
        // This page is entirely self-contained. Loading its text avoids WebKit's
        // inconsistent handling of query parameters on loadFileURL.
        let modeExpression = "new URLSearchParams(location.search).get(\"mode\")"
        guard originalHTML.contains(modeExpression) else { finish("incompatible-animation"); return }
        let html = originalHTML.replacingOccurrences(of: modeExpression, with: "window.__550cMode")
        let screen = NSScreen.main ?? NSScreen.screens.first
        let fullFrame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = options.windowed ? NSRect(x: fullFrame.midX - 600, y: fullFrame.midY - 375, width: 1200, height: 750) : fullFrame
        let playerWindow = BootWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        playerWindow.title = "ChatGPT 550C"
        playerWindow.backgroundColor = .black
        playerWindow.isReleasedWhenClosed = false
        playerWindow.hasShadow = options.windowed
        playerWindow.level = options.windowed ? .normal : .floating
        playerWindow.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
        window = playerWindow

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.userContentController.add(self, name: "diagnostics")
        config.userContentController.addUserScript(WKUserScript(source: """
        window.__550cMode = '\(mode.rawValue)';
        window.addEventListener('error', e => window.webkit.messageHandlers.diagnostics.postMessage(String(e.message)));
        window.addEventListener('unhandledrejection', e => window.webkit.messageHandlers.diagnostics.postMessage(String(e.reason)));
        """, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let safeTop = options.windowed ? 12 : max(12, (screen?.safeAreaInsets.top ?? 0) + 8)
        config.userContentController.addUserScript(WKUserScript(source: """
        const macStyle = document.createElement('style');
        macStyle.textContent = '#skipBtn{z-index:10000;top:\(safeTop)px;opacity:.8;}';
        document.head.appendChild(macStyle);
        const skip = document.getElementById('skipBtn');
        if (skip) { skip.setAttribute('role','button'); skip.setAttribute('aria-label','跳过动画并打开 ChatGPT'); skip.tabIndex = 0; skip.addEventListener('keydown',e => {if(e.key==='Enter') skip.click();}); }
        """, injectionTime: .atDocumentEnd, forMainFrameOnly: true))

        let view = WKWebView(frame: NSRect(origin: .zero, size: frame.size), configuration: config)
        view.autoresizingMask = [.width, .height]
        view.navigationDelegate = self
        view.uiDelegate = self
        view.setValue(false, forKey: "drawsBackground")
        webView = view
        playerWindow.contentView = view
        titleObservation = view.observe(\.title, options: [.new]) { [weak self] view, _ in
            if view.title == "__550C_DONE__" { self?.finish("animation-complete") }
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.finish("escape"); return nil }
            return event
        }
        let timeout = options.testing && options.value("--test-action") == "timeout" ? 1.0 : 150.0
        deadline = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in self?.finish("timeout") }
        if !options.windowed { NSApp.presentationOptions = [.autoHideDock, .autoHideMenuBar] }
        playerWindow.makeKeyAndOrderFront(nil)
        playerWindow.makeFirstResponder(view)
        NSApp.activate(ignoringOtherApps: true)
        view.loadHTMLString(html, baseURL: resources)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard options.testing, let action = options.value("--test-action") else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self, weak webView] in
            guard let self, !self.finished else { return }
            if action == "skip" { webView?.evaluateJavaScript("document.getElementById('skipBtn').click()") }
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // The player is offline; no remote navigation or popup can escape into another page.
        let url = action.request.url
        decisionHandler(url?.isFileURL == true || url?.absoluteString == "about:blank" ? .allow : .cancel)
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish("load-error") }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish("load-error") }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { finish("web-process-ended") }
    func webViewDidClose(_ webView: WKWebView) { finish("page-closed") }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        scriptErrors.append(String(describing: message.body))
    }

    @objc func skip() { finish("skip-menu") }
    @objc func cancel() {
        if shouldPrepareTarget { perform(.cancelled); return }
        guard !finished else { return }
        finished = true
        cleanUp()
        NSApp.terminate(nil)
    }

    func cleanUp() {
        deadline?.invalidate()
        deadline = nil
        titleObservation?.invalidate()
        titleObservation = nil
        if let monitor = keyMonitor { NSEvent.removeMonitor(monitor); keyMonitor = nil }
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "diagnostics")
        webView?.stopLoading()
        targetProbe?.invalidate()
        waitDeadline?.invalidate()
        activationProbe?.invalidate()
        if let observer = activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            activationObserver = nil
        }
        window?.orderOut(nil)
        NSApp.presentationOptions = previousPresentation
    }

    func finish(_ reason: String) {
        guard !finished else { return }
        finished = true
        telemetry["playbackEndedAt"] = elapsed
        deadline?.invalidate()
        if options.testing {
            let script = """
            JSON.stringify({title:document.title,mode:window.__550cMode,nodes:document.querySelectorAll('.uav').length,completedNodes:document.querySelectorAll('.uav.done').length,progress:document.querySelector('#b-pct')?.textContent,finalVisible:document.getElementById('final')?.classList.contains('show'),skipOnTop:(()=>{let b=document.getElementById('skipBtn');if(!b)return false;let r=b.getBoundingClientRect();return document.elementFromPoint(r.x+r.width/2,r.y+r.height/2)===b;})()})
            """
            if let webView {
                webView.evaluateJavaScript(script) { [weak self] result, error in
                    self?.writeReport(reason, page: result as? String, error: error)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.writeReport(reason, page: nil, error: nil) }
            } else { writeReport(reason, page: nil, error: nil) }
            return
        }
        if options.preview { cleanUp(); NSApp.terminate(nil); return }
        perform(.playbackEnded)
    }

    var wroteReport = false
    func writeReport(_ reason: String, page: String?, error: Error?) {
        guard !wroteReport else { return }
        wroteReport = true
        var report: [String: Any] = ["mode": mode.rawValue, "reason": reason, "seconds": Date().timeIntervalSince(startTime), "scriptErrors": scriptErrors]
        if let page, let data = page.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) { report["page"] = json }
        if let error { report["inspectionError"] = String(describing: error) }
        if let path = options.reportPath, let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
        if options.liveHandoffTest {
            verificationReport = report
            perform(.playbackEnded)
        } else {
            cleanUp()
            NSApp.terminate(nil)
        }
    }

    func resolveChatGPT() -> URL? {
        let fm = FileManager.default
        let candidates = [URL(fileURLWithPath: "/Applications/ChatGPT.app"), fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications/ChatGPT.app")]
        let registered = ["com.openai.chat", "com.openai.codex"].compactMap {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)
        }.filter { url in
            let bundle = Bundle(url: url)
            let name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            return url.deletingPathExtension().lastPathComponent == "ChatGPT" || name == "ChatGPT"
        }
        let target = candidates.first(where: { fm.fileExists(atPath: $0.path) }) ?? registered.first
        guard let target, target.standardizedFileURL != Bundle.main.bundleURL.standardizedFileURL else { return nil }
        return target
    }

    func prepareChatGPT() {
        telemetry["prelaunchStartedAt"] = elapsed
        guard let target = resolveChatGPT() else {
            targetError = "未找到 ChatGPT 应用。请将 ChatGPT 安装到“应用程序”文件夹后重试。"
            perform(.targetFailed)
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        config.hides = false
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let self, self.handoff.phase == .playing || self.handoff.phase == .waiting,
                  let window = self.window,
                  let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  application.bundleURL?.standardizedFileURL == target.standardizedFileURL else { return }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        NSWorkspace.shared.openApplication(at: target, configuration: config) { application, error in
            DispatchQueue.main.async {
                guard self.handoff.phase != .cancelled && self.handoff.phase != .done && self.handoff.phase != .failed else { return }
                if let error {
                    self.targetError = "无法打开 ChatGPT：\(error.localizedDescription)"
                    self.perform(.targetFailed)
                    return
                }
                guard let application else { self.perform(.targetFailed); return }
                self.targetApp = application
                self.telemetry["processReadyAt"] = self.elapsed
                self.targetProbe = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in self?.probeTarget() }
                self.probeTarget()
                // Some applications activate themselves during startup. Cover them again.
                if !self.finished && NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier {
                    self.window?.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }

    func probeTarget() {
        guard !probeBusy, let application = targetApp, handoff.phase == .playing || handoff.phase == .waiting else { return }
        if application.isTerminated {
            targetProbe?.invalidate()
            targetError = "ChatGPT 在准备窗口时退出。请重新打开启动器。"
            perform(.targetFailed)
            return
        }
        probeBusy = true
        targetWindows.prepare(pid: application.processIdentifier, frame: screenFrame, desktopTop: desktopTop) { [weak self] result in
            guard let self else { return }
            self.probeBusy = false
            guard self.handoff.phase == .playing || self.handoff.phase == .waiting else { return }
            self.recordWindow(result)
            if result.ready {
                self.targetProbe?.invalidate()
                self.telemetry["windowReadyAt"] = self.elapsed
                self.perform(.targetReady)
            }
        }
    }

    func recordWindow(_ result: WindowPreparation) {
        telemetry["windowFill"] = result.fill
        if let frame = result.frame { telemetry["windowFrame"] = [frame.minX, frame.minY, frame.width, frame.height] }
    }

    func perform(_ event: HandoffEvent) {
        let effects = handoff.handle(event)
        for effect in effects {
            switch effect {
            case .waitForTarget:
                telemetry["waitStartedAt"] = elapsed
                showWaitingLabel()
                waitDeadline = Timer.scheduledTimer(withTimeInterval: 8, repeats: false) { [weak self] _ in
                    guard let self else { return }
                    self.targetError = "ChatGPT 窗口尚未准备好。它已在后台启动，可以从 Dock 打开。"
                    self.perform(.waitingExpired)
                }
            case .revealTarget:
                waitDeadline?.invalidate()
                revealChatGPT()
            case .dismissOverlay:
                cleanUp()
            case .showFailure:
                persistLiveReport()
                showLaunchError(targetError ?? "无法准备 ChatGPT 窗口，请重试。")
            }
        }
        if handoff.phase == .done || handoff.phase == .cancelled {
            telemetry["handoffCompletedAt"] = elapsed
            persistLiveReport()
            NSApp.terminate(nil)
        }
    }

    func showWaitingLabel() {
        guard let view = window?.contentView else { return }
        let label = NSTextField(labelWithString: "ChatGPT 正在准备…")
        label.textColor = NSColor(calibratedRed: 0.95, green: 0.67, blue: 0.2, alpha: 1)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.alignment = .center
        label.frame = NSRect(x: 0, y: 55, width: view.bounds.width, height: 22)
        label.autoresizingMask = [.width, .maxYMargin]
        view.addSubview(label)
    }

    func revealChatGPT() {
        guard let application = targetApp, !application.isTerminated else { perform(.targetFailed); return }
        targetWindows.prepare(pid: application.processIdentifier, frame: screenFrame, desktopTop: desktopTop) { [weak self] result in
            guard let self, self.handoff.phase == .revealing else { return }
            self.recordWindow(result)
            self.window?.level = .statusBar
            self.telemetry["activatedAt"] = self.elapsed
            if #available(macOS 14, *) {
                application.activate(from: .current, options: [])
            } else {
                application.activate(options: [.activateIgnoringOtherApps])
            }
            let activationStarted = Date()
            self.activationProbe = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] timer in
                guard let self, self.handoff.phase == .revealing else { timer.invalidate(); return }
                guard !application.isTerminated else {
                    timer.invalidate()
                    self.targetError = "ChatGPT 在切换窗口时退出，请重试。"
                    self.perform(.targetFailed)
                    return
                }
                let visible = NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier && TargetWindowManager.hasVisibleWindow(pid: application.processIdentifier)
                guard visible else {
                    if Date().timeIntervalSince(activationStarted) >= 2 {
                        timer.invalidate()
                        self.targetError = "ChatGPT 尚未显示窗口，请从 Dock 打开后再试。"
                        self.perform(.targetFailed)
                    }
                    return
                }
                timer.invalidate()
                self.telemetry["targetVisibleAt"] = self.elapsed
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in self?.fadeOverlay() }
            }
        }
    }

    func fadeOverlay() {
        guard handoff.phase == .revealing else { return }
        telemetry["fadeStartedAt"] = elapsed
        guard let window else { perform(.revealCompleted); return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in self?.perform(.revealCompleted) })
    }

    func persistLiveReport() {
        guard options.liveHandoffTest, let path = options.reportPath else { return }
        var report = verificationReport ?? [:]
        report["handoff"] = telemetry
        report["handoffPhase"] = String(describing: handoff.phase)
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }

    @objc func requestWindowAccess() {
        // Permission prompts must never be covered by the animation window.
        if window != nil {
            _ = handoff.handle(.cancelled)
            cleanUp()
        }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        NSApp.terminate(nil)
    }

    func showLaunchError(_ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "ChatGPT 550C"
        alert.informativeText = text
        alert.addButton(withTitle: "好")
        alert.runModal()
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) { cleanUp() }
}

@main
struct BootApplication {
    static func main() {
        let app = NSApplication.shared
        let launcher = Launcher()
        app.setActivationPolicy(.regular)
        app.delegate = launcher
        app.run()
    }
}
