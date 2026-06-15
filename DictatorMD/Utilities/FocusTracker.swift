import AppKit

struct InsertionTarget {
    let app: NSRunningApplication?
    let focusedElement: AXUIElement?
    let focusedWindow: AXUIElement?
    let selectedTextRange: CFRange?
    let clickAnchor: ClickAnchor?

    var appName: String? { app?.localizedName }
    var bundleIdentifier: String? { app?.bundleIdentifier }
}

struct ClickAnchor {
    let app: NSRunningApplication
    let screenPoint: CGPoint
    let capturedAt: Date
}

final class FocusTracker {
    static let shared = FocusTracker()

    private(set) var lastTargetApp: NSRunningApplication?
    private var lastClickAnchor: ClickAnchor?
    private var globalMouseMonitor: Any?
    private let ownBundleID = Bundle.main.bundleIdentifier
    private let clickAnchorMaxAge: TimeInterval = 10 * 60

    private init() {
        update(from: NSWorkspace.shared.frontmostApplication)
        startMouseTrackingFallback()
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
            selectedTextRange: focusedElement.flatMap(Self.selectedTextRange(from:)),
            clickAnchor: validClickAnchor(for: app)
        )
    }

    func recordMouseDown(screenPoint: CGPoint) {
        guard !Self.isInsideOwnWindow(screenPoint),
              !Self.isInsideOwnWindow(NSEvent.mouseLocation) else {
            return
        }

        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != ownBundleID,
              !app.isTerminated else {
            return
        }

        lastClickAnchor = ClickAnchor(app: app, screenPoint: screenPoint, capturedAt: Date())
        update(from: app)
        DebugLog.shared.log("[FocusTracker] clickAnchor app=\(app.localizedName ?? "nil") bundle=\(app.bundleIdentifier ?? "nil") point=\(Int(screenPoint.x)),\(Int(screenPoint.y))")
    }

    private func update(from app: NSRunningApplication?) {
        guard let app,
              app.bundleIdentifier != ownBundleID,
              !app.isTerminated else {
            return
        }
        lastTargetApp = app
    }

    private func validClickAnchor(for app: NSRunningApplication?) -> ClickAnchor? {
        guard let app,
              let anchor = lastClickAnchor,
              !anchor.app.isTerminated,
              Date().timeIntervalSince(anchor.capturedAt) <= clickAnchorMaxAge,
              (anchor.app.processIdentifier == app.processIdentifier || anchor.app.bundleIdentifier == app.bundleIdentifier) else {
            return nil
        }
        return anchor
    }

    private func startMouseTrackingFallback() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            let point = CGEvent(source: nil)?.location ?? NSEvent.mouseLocation
            self?.recordMouseDown(screenPoint: point)
        }
    }

    private static func isInsideOwnWindow(_ point: CGPoint) -> Bool {
        NSApp.windows.contains { window in
            window.isVisible && window.frame.contains(point)
        }
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
