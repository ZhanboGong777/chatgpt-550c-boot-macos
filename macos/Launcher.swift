import AppKit
import WebKit

// A standalone macOS player for the unmodified upstream animation.
// ChatGPT is opened through Launch Services after playback; its files are never edited.
enum BootMode: String, CaseIterable { case full, simple, off }

struct Options {
    let arguments = CommandLine.arguments
    func value(_ flag: String) -> String? {
        guard let i = arguments.firstIndex(of: flag), i + 1 < arguments.count else { return nil }
        return arguments[i + 1]
    }
    var reportPath: String? { value("--verify") }
    var testing: Bool { reportPath != nil }
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        previousPresentation = NSApp.presentationOptions
        mode = BootMode(rawValue: options.value("--mode") ?? UserDefaults.standard.string(forKey: "mode") ?? "full") ?? .full
        if !options.testing && NSEvent.modifierFlags.contains(.option) {
            guard chooseMode() else { NSApp.terminate(nil); return }
        }
        startTime = Date()
        guard mode != .off else { finish("off"); return }
        showAnimation()
    }

    func buildMenu() {
        let menu = NSMenu()
        let item = NSMenuItem()
        menu.addItem(item)
        let appMenu = NSMenu(title: "ChatGPT 550C")
        appMenu.addItem(withTitle: "跳过动画并打开 ChatGPT", action: #selector(skip), keyEquivalent: "w").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出动画", action: #selector(cancel), keyEquivalent: "q").target = self
        item.submenu = appMenu
        NSApp.mainMenu = menu
    }

    func chooseMode() -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "ChatGPT 550C 动画模式"
        alert.informativeText = "选择将用于以后打开的模式。按住 Option 打开启动器，可再次更改。"
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 300, height: 28))
        popup.addItems(withTitles: ["完整 550C 动画", "快速模式（仅 Logo）", "直接打开 ChatGPT"])
        popup.selectItem(at: BootMode.allCases.firstIndex(of: mode) ?? 0)
        alert.accessoryView = popup
        alert.addButton(withTitle: "保存并打开")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return false }
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
        playerWindow.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
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
        window?.orderOut(nil)
        NSApp.presentationOptions = previousPresentation
    }

    func finish(_ reason: String) {
        guard !finished else { return }
        finished = true
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
        cleanUp()
        if options.preview { NSApp.terminate(nil); return }
        launchChatGPT()
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
        cleanUp()
        NSApp.terminate(nil)
    }

    func launchChatGPT() {
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
        guard let target, target.standardizedFileURL != Bundle.main.bundleURL.standardizedFileURL else {
            showLaunchError("未找到 ChatGPT 应用。请将 ChatGPT 安装到“应用程序”文件夹后重试。")
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: target, configuration: config) { _, error in
            DispatchQueue.main.async {
                if let error { self.showLaunchError("无法打开 ChatGPT：\(error.localizedDescription)") }
                else { NSApp.terminate(nil) }
            }
        }
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

let app = NSApplication.shared
let launcher = Launcher()
app.setActivationPolicy(.regular)
app.delegate = launcher
app.run()
