import AppKit

struct InsertionTarget {
    let app: NSRunningApplication?
    let focusedElement: AXUIElement?
    let focusedWindow: AXUIElement?
    let selectedTextRange: CFRange?
    let clickAnchor: ClickAnchor?
    var windowFrame: CGRect? = nil
    var fieldFrame: CGRect? = nil

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
    static let syntheticClickMarker: Int64 = 0x444D44434C49434B

    static func isSyntheticClick(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == syntheticClickMarker
    }

    private(set) var lastTargetApp: NSRunningApplication?
    private var lastClickAnchor: ClickAnchor?
    private var globalMouseMonitor: Any?
    private let clickAnchorMaxAge: TimeInterval = 10 * 60
    private var accessibilityEnabledPIDs = Set<pid_t>()

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
        if frontmost?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            update(from: frontmost)
            return frontmost
        }
        return lastTargetApp
    }

    func currentInsertionTarget() -> InsertionTarget {
        let app = currentTargetApp()
        if let app { enableWebAccessibility(in: app) }
        func captureField() -> AXUIElement? {
            let systemField = Self.focusedElement().flatMap { element -> AXUIElement? in
                guard let app else { return nil }
                var pid: pid_t = 0
                return AXUIElementGetPid(element, &pid) == .success && pid == app.processIdentifier
                    ? element : nil
            }
            return systemField ?? app.flatMap(Self.focusedElement(in:))
        }
        var focusedElement = captureField()
        // Electron builds its AX tree asynchronously after the opt-in. Do not
        // permanently capture a missing editor merely because the first query raced it.
        if let app, accessibilityEnabledPIDs.contains(app.processIdentifier), focusedElement == nil {
            let deadline = Date().addingTimeInterval(0.30)
            repeat {
                Thread.sleep(forTimeInterval: 0.025)
                focusedElement = captureField()
            } while focusedElement == nil && Date() < deadline
        }
        // Browser controls can report transient/popup owner windows. The app's
        // keyboard-focused window is the durable destination to raise later.
        let window = app.flatMap(Self.focusedWindow(in:)) ?? focusedElement.flatMap(Self.window(from:))
        let windowFrame = window.flatMap(Self.frame(of:))
        let fieldFrame = focusedElement.flatMap(Self.frame(of:))
        let selectedRange = focusedElement.flatMap(Self.selectedTextRange(from:))
        var anchor = validClickAnchor(for: app).flatMap { anchor -> ClickAnchor? in
            guard windowFrame?.contains(anchor.screenPoint) == true else { return nil }
            if let fieldFrame, !fieldFrame.contains(anchor.screenPoint) { return nil }
            return anchor
        }
        if anchor == nil, let app, let fieldFrame, let windowFrame, selectedRange != nil {
            let point = CGPoint(x: fieldFrame.midX, y: fieldFrame.midY)
            if windowFrame.contains(point) {
                anchor = ClickAnchor(app: app, screenPoint: point, capturedAt: Date())
            }
        }
        return InsertionTarget(
            app: app,
            focusedElement: focusedElement,
            focusedWindow: window,
            selectedTextRange: selectedRange,
            clickAnchor: anchor,
            windowFrame: windowFrame,
            fieldFrame: fieldFrame
        )
    }

    private func enableWebAccessibility(in app: NSRunningApplication) {
        guard AXIsProcessTrusted(), !accessibilityEnabledPIDs.contains(app.processIdentifier) else { return }
        // Electron documents this opt-in; unsupported native apps simply ignore it.
        let element = AXUIElementCreateApplication(app.processIdentifier)
        let result = AXUIElementSetAttributeValue(element, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        if result == .success {
            accessibilityEnabledPIDs.insert(app.processIdentifier)
            Thread.sleep(forTimeInterval: 0.08)
            DebugLog.shared.log("[FocusTracker] enabledWebAccessibility pid=\(app.processIdentifier)")
        }
    }

    func recordMouseDown(screenPoint: CGPoint) {
        guard !Self.isInsideOwnWindow(screenPoint) else {
            return
        }

        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              !app.isTerminated else {
            return
        }

        lastClickAnchor = ClickAnchor(app: app, screenPoint: screenPoint, capturedAt: Date())
        update(from: app)
        DebugLog.shared.log("[FocusTracker] clickAnchor app=\(app.localizedName ?? "nil") bundle=\(app.bundleIdentifier ?? "nil") point=\(Int(screenPoint.x)),\(Int(screenPoint.y))")
    }

    private func update(from app: NSRunningApplication?) {
        guard let app,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
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
              anchor.app.processIdentifier == app.processIdentifier else {
            return nil
        }
        return anchor
    }

    private func startMouseTrackingFallback() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            if let cgEvent = event.cgEvent, Self.isSyntheticClick(cgEvent) { return }
            guard let point = event.cgEvent?.location else { return }
            self?.recordMouseDown(screenPoint: point)
        }
    }

    private static func isInsideOwnWindow(_ point: CGPoint) -> Bool {
        // CGEvent and AX use top-left coordinates; AppKit window frames use bottom-left.
        let appKitPoint = CGPoint(x: point.x, y: (NSScreen.screens.first?.frame.maxY ?? 0) - point.y)
        return NSApp.windows.contains { window in
            window.isVisible && window.frame.contains(appKitPoint)
        }
    }

    static func frame(of element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue, let sizeValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(), CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }
        let position = positionValue as! AXValue
        let size = sizeValue as! AXValue
        guard AXValueGetType(position) == .cgPoint, AXValueGetType(size) == .cgSize else { return nil }
        var point = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(position, .cgPoint, &point), AXValueGetValue(size, .cgSize, &dimensions),
              dimensions.width > 0, dimensions.height > 0 else { return nil }
        return CGRect(origin: point, size: dimensions)
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

    private static func focusedElement(in app: NSRunningApplication) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value else { return nil }
        return (value as! AXUIElement)
    }

    private static func focusedWindow(in app: NSRunningApplication) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let value else { return nil }
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
        guard result == .success, let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axValue = value as! AXValue
        guard AXValueGetType(axValue) == .cfRange else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &range) else { return nil }
        return range
    }
}
