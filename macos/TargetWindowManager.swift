import AppKit
import ApplicationServices

struct WindowPreparation {
    let ready: Bool
    let fill: String
    let frame: CGRect?
}

// Only the requested ChatGPT main window is inspected or resized. All AX calls
// have a bounded timeout and run off the animation's main thread.
final class TargetWindowManager {
    private let queue = DispatchQueue(label: "chatgpt550c.window-preparation", qos: .userInitiated)

    static var hasPermission: Bool { AXIsProcessTrusted() }

    func prepare(pid: pid_t, frame: CGRect, desktopTop: CGFloat,
                 completion: @escaping (WindowPreparation) -> Void) {
        queue.async {
            let result = self.prepareSynchronously(pid: pid, frame: frame, desktopTop: desktopTop)
            DispatchQueue.main.async { completion(result) }
        }
    }

    static func hasVisibleWindow(pid: pid_t) -> Bool {
        cgWindowFrame(pid: pid, onScreenOnly: true) != nil
    }

    private static func cgWindowFrame(pid: pid_t, onScreenOnly: Bool) -> CGRect? {
        let options: CGWindowListOption = onScreenOnly ? [.optionOnScreenOnly, .excludeDesktopElements] : [.excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return nil }
        return windows.compactMap { item -> CGRect? in
            guard (item[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
                  (item[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  let bounds = item[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary), rect.width >= 300, rect.height >= 180 else { return nil }
            return rect
        }.max(by: { $0.width * $0.height < $1.width * $1.height })
    }

    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private func mainWindow(_ application: AXUIElement) -> AXUIElement? {
        for name in [kAXMainWindowAttribute, kAXFocusedWindowAttribute] {
            if let value = attribute(application, name), CFGetTypeID(value) == AXUIElementGetTypeID() {
                return (value as! AXUIElement)
            }
        }
        guard let windows = attribute(application, kAXWindowsAttribute) as? [AXUIElement] else { return nil }
        return windows.first { (attribute($0, kAXSubroleAttribute) as? String) == kAXStandardWindowSubrole }
    }

    private func windowFrame(_ window: AXUIElement) -> CGRect? {
        guard let position = attribute(window, kAXPositionAttribute), CFGetTypeID(position) == AXValueGetTypeID(),
              let size = attribute(window, kAXSizeAttribute), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point),
              AXValueGetValue(size as! AXValue, .cgSize, &dimensions) else { return nil }
        return CGRect(origin: point, size: dimensions)
    }

    private func prepareSynchronously(pid: pid_t, frame: CGRect, desktopTop: CGFloat) -> WindowPreparation {
        guard Self.hasPermission else {
            let existing = Self.cgWindowFrame(pid: pid, onScreenOnly: false)
            return WindowPreparation(ready: existing != nil, fill: "permission-required", frame: existing)
        }
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 0.2)
        guard let window = mainWindow(application) else {
            return WindowPreparation(ready: false, fill: "window-pending", frame: nil)
        }
        AXUIElementSetMessagingTimeout(window, 0.2)
        if (attribute(window, "AXFullScreen") as? Bool) == true {
            // Do not force an existing full-screen session through another Space transition.
            return WindowPreparation(ready: true, fill: "already-fullscreen", frame: windowFrame(window))
        }
        if (attribute(window, kAXMinimizedAttribute) as? Bool) == true {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        var position = CGPoint(x: frame.minX, y: desktopTop - frame.maxY)
        var size = frame.size
        guard let positionValue = AXValueCreate(.cgPoint, &position), let sizeValue = AXValueCreate(.cgSize, &size) else {
            return WindowPreparation(ready: true, fill: "resize-unavailable", frame: windowFrame(window))
        }
        // A second size write accommodates apps that constrain a move to another display.
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        let result = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        let actual = windowFrame(window)
        let expected = CGRect(origin: position, size: size)
        let matches = actual.map {
            abs($0.minX - expected.minX) <= 3 && abs($0.minY - expected.minY) <= 3 &&
            abs($0.width - expected.width) <= 3 && abs($0.height - expected.height) <= 3
        } ?? false
        return WindowPreparation(ready: true, fill: result == .success && matches ? "filled" : "resize-deferred", frame: actual)
    }
}
