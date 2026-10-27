import AppKit

// A local test app that can replace its own process before creating a window.
// It never opens or controls ChatGPT, and all fixture instances stop on request.
private struct FixtureConfiguration: Decodable {
    let scenario: String
    let events: String
}

private final class Fixture: NSObject, NSApplicationDelegate {
    let configuration: FixtureConfiguration
    var window: NSWindow?
    var stopTimer: Timer?

    override init() {
        let resource = Bundle.main.url(forResource: "FixtureConfig", withExtension: "json")!
        configuration = try! JSONDecoder().decode(FixtureConfiguration.self, from: Data(contentsOf: resource))
        super.init()
    }

    func record(_ event: String) {
        let value: [String: Any] = ["event": event, "pid": Int(getpid()), "time": Date().timeIntervalSince1970]
        let file = URL(fileURLWithPath: configuration.events).appendingPathComponent("\(getpid())-\(event).json")
        if let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) {
            try? data.write(to: file, options: .atomic)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let successor = CommandLine.arguments.contains("--successor")
        record(successor ? "successor-started" : "initial-started")
        stopTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if FileManager.default.fileExists(atPath: self.configuration.events + "/stop") {
                NSApp.terminate(nil)
            }
        }
        // A failed test cannot leave the fixture running indefinitely.
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { NSApp.terminate(nil) }
        if successor || configuration.scenario == "stable" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.showWindow() }
        } else if configuration.scenario == "replacement" || configuration.scenario == "ready-replacement" {
            if configuration.scenario == "ready-replacement" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.showWindow() }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.startSuccessor() }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { NSApp.terminate(nil) }
        }
    }

    func startSuccessor() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.activates = false
        configuration.arguments = ["--successor"]
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { [weak self] application, error in
            DispatchQueue.main.async {
                self?.record(application != nil && error == nil ? "successor-launched" : "successor-launch-failed")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { NSApp.terminate(nil) }
            }
        }
    }

    func showWindow() {
        let value = NSWindow(contentRect: NSRect(x: 180, y: 180, width: 640, height: 420),
                             styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        value.title = "550C lifecycle verification fixture"
        value.contentView?.addSubview(NSTextField(labelWithString: "Local launcher lifecycle test"))
        value.orderFront(nil)
        window = value
        record("window-created")
    }

    func applicationWillTerminate(_ notification: Notification) { record("exited") }
}

@main
private struct FixtureApplication {
    static func main() {
        let app = NSApplication.shared
        let delegate = Fixture()
        app.setActivationPolicy(.regular)
        app.delegate = delegate
        app.run()
    }
}
