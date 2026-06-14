import AppKit

struct InsertionTarget {
    let app: NSRunningApplication?
    let focusedElement: AXUIElement?
    let focusedWindow: AXUIElement?
    let selectedTextRange: CFRange?

    var appName: String? { app?.localizedName }
    var bundleIdentifier: String? { app?.bundleIdentifier }
}

final class FocusTracker {
    static let shared = FocusTracker()

    private(set) var lastTargetApp: NSRunningApplication?
    private let ownBundleID = Bundle.main.bundleIdentifier

    private init() {
        update(from: NSWorkspace.shared.frontmostApplication)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeAppChanged(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func activeAppChanged(_ notification: Notification) {
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        update(from: app)
    }

    func currentTargetApp() -> NSRunningApplication? {
        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost?.bundleIdentifier != ownBundleID {
            update(from: frontmost)
            return frontmost
        }
        return lastTargetApp
    }

    func currentInsertionTarget() -> InsertionTarget {
        let app = currentTargetApp()
        let focusedElement = Self.focusedElement()
        return InsertionTarget(
            app: app,
            focusedElement: focusedElement,
            focusedWindow: focusedElement.flatMap(Self.window(from:)),
            selectedTextRange: focusedElement.flatMap(Self.selectedTextRange(from:))
        )
    }

    private func update(from app: NSRunningApplication?) {
        guard let app,
              app.bundleIdentifier != ownBundleID,
              !app.isTerminated else {
            return
        }
        lastTargetApp = app
    }

    private static func focusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &value
        )
        guard result == .success, let value else { return nil }
        return (value as! AXUIElement)
    }

    private static func window(from element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXWindowAttribute as CFString,
            &value
        )
        guard result == .success, let value else { return nil }
        return (value as! AXUIElement)
    }

    private static func selectedTextRange(from element: AXUIElement) -> CFRange? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &value
        )
        guard result == .success, let value else { return nil }
        let axValue = value as! AXValue
        guard AXValueGetType(axValue) == .cfRange else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &range) else { return nil }
        return range
    }
}
