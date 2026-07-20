#!/usr/bin/env swift

import AppKit
import ApplicationServices
import Foundation

private let bundleIdentifier = "com.dictatormd.DictatorMD"
private let appURL = URL(fileURLWithPath: "/Applications/Dictator-md.app")

private func attribute(_ name: String, of element: AXUIElement) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
    return value
}

private func stringAttribute(_ name: String, of element: AXUIElement) -> String? {
    attribute(name, of: element) as? String
}

private func pointAttribute(_ name: String, of element: AXUIElement) -> CGPoint? {
    guard let value = attribute(name, of: element) else { return nil }
    var result = CGPoint.zero
    guard AXValueGetValue(value as! AXValue, .cgPoint, &result) else { return nil }
    return result
}

private func sizeAttribute(_ name: String, of element: AXUIElement) -> CGSize? {
    guard let value = attribute(name, of: element) else { return nil }
    var result = CGSize.zero
    guard AXValueGetValue(value as! AXValue, .cgSize, &result) else { return nil }
    return result
}

private func children(of element: AXUIElement) -> [AXUIElement] {
    attribute(kAXChildrenAttribute, of: element) as? [AXUIElement] ?? []
}

private func descendants(of root: AXUIElement) -> [AXUIElement] {
    var result: [AXUIElement] = []
    var queue = children(of: root)
    var index = 0
    while index < queue.count {
        let element = queue[index]
        result.append(element)
        queue.append(contentsOf: children(of: element))
        index += 1
    }
    return result
}

private func labels(of element: AXUIElement) -> [String] {
    [
        stringAttribute(kAXTitleAttribute, of: element),
        stringAttribute(kAXDescriptionAttribute, of: element),
        stringAttribute(kAXValueAttribute, of: element)
    ].compactMap { $0 }
}

private func waitUntil(timeout: TimeInterval, condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
        if condition() { return true }
        Thread.sleep(forTimeInterval: 0.1)
    } while Date() < deadline
    return false
}

private func launchFreshApp() throws -> NSRunningApplication {
    NSRunningApplication
        .runningApplications(withBundleIdentifier: bundleIdentifier)
        .forEach { $0.terminate() }
    _ = waitUntil(timeout: 3) {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
    }

    let semaphore = DispatchSemaphore(value: 0)
    var launchedApp: NSRunningApplication?
    var launchError: Error?
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { app, error in
        launchedApp = app
        launchError = error
        semaphore.signal()
    }

    guard semaphore.wait(timeout: .now() + 10) == .success else {
        throw NSError(domain: "DashboardResizeUISmoke", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Timed out launching Dictator-md"
        ])
    }
    if let launchError { throw launchError }
    guard let launchedApp else {
        throw NSError(domain: "DashboardResizeUISmoke", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "Dictator-md did not return a running application"
        ])
    }
    return launchedApp
}

private func mainWindow(of appElement: AXUIElement) -> AXUIElement? {
    let windows = attribute(kAXWindowsAttribute, of: appElement) as? [AXUIElement] ?? []
    return windows.first { stringAttribute(kAXTitleAttribute, of: $0) == "Dictator-md" }
}

private func setWindow(_ window: AXUIElement, width: CGFloat, height: CGFloat) {
    var position = CGPoint(x: 80, y: 80)
    var size = CGSize(width: width, height: height)
    if let positionValue = AXValueCreate(.cgPoint, &position) {
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
    }
    if let sizeValue = AXValueCreate(.cgSize, &size) {
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
    }
}

private func pressButton(label: String, in root: AXUIElement) -> Bool {
    guard let button = descendants(of: root).first(where: {
        stringAttribute(kAXRoleAttribute, of: $0) == kAXButtonRole
            && labels(of: $0).contains(label)
    }) else {
        return false
    }
    return AXUIElementPerformAction(button, kAXPressAction as CFString) == .success
}

private func verifySidebarVisible(in window: AXUIElement, width: Int, height: Int) throws {
    setWindow(window, width: CGFloat(width), height: CGFloat(height))
    Thread.sleep(forTimeInterval: 0.6)

    guard pressButton(label: "Open Dashboard", in: window) else {
        throw NSError(domain: "DashboardResizeUISmoke", code: 3, userInfo: [
            NSLocalizedDescriptionKey: "Dashboard navigation button is missing or not pressable at \(width)x\(height)"
        ])
    }
    Thread.sleep(forTimeInterval: 0.4)

    guard let windowPosition = pointAttribute(kAXPositionAttribute, of: window),
          let windowSize = sizeAttribute(kAXSizeAttribute, of: window) else {
        throw NSError(domain: "DashboardResizeUISmoke", code: 4, userInfo: [
            NSLocalizedDescriptionKey: "Could not read window bounds"
        ])
    }

    // AX child frames are measured against the content view while the window frame
    // includes a native title-bar/shadow boundary. Permit that narrow edge
    // difference while still rejecting genuinely clipped sidebar controls.
    let windowFrame = CGRect(origin: windowPosition, size: windowSize).insetBy(dx: -10, dy: -10)
    let navLabels = ["Open Dashboard", "Open History", "Open Vocabulary", "Open Models", "Open Control Center", "Open Settings"]
    let buttons = descendants(of: window).filter {
        stringAttribute(kAXRoleAttribute, of: $0) == kAXButtonRole
            && !Set(labels(of: $0)).isDisjoint(with: navLabels)
    }

    guard buttons.count >= navLabels.count else {
        throw NSError(domain: "DashboardResizeUISmoke", code: 5, userInfo: [
            NSLocalizedDescriptionKey: "Expected sidebar navigation buttons at \(width)x\(height), found \(buttons.count)"
        ])
    }

    for button in buttons {
        guard let buttonPosition = pointAttribute(kAXPositionAttribute, of: button),
              let buttonSize = sizeAttribute(kAXSizeAttribute, of: button) else {
            throw NSError(domain: "DashboardResizeUISmoke", code: 6, userInfo: [
                NSLocalizedDescriptionKey: "Could not read sidebar button bounds"
            ])
        }
        let buttonFrame = CGRect(origin: buttonPosition, size: buttonSize)
        guard windowFrame.contains(buttonFrame) else {
            throw NSError(domain: "DashboardResizeUISmoke", code: 7, userInfo: [
                NSLocalizedDescriptionKey: "Sidebar button escaped visible window bounds at \(width)x\(height): \(buttonFrame) outside \(windowFrame)"
            ])
        }
    }

    print("PASS \(width)x\(height) sidebarButtons=\(buttons.count)")
}

guard AXIsProcessTrusted() else {
    fputs("UI smoke test requires Accessibility permission for the invoking terminal.\n", stderr)
    exit(1)
}

do {
    let app = try launchFreshApp()
    app.activate(options: [.activateAllWindows])
    let appElement = AXUIElementCreateApplication(app.processIdentifier)
    guard waitUntil(timeout: 5, condition: { mainWindow(of: appElement) != nil }),
          let window = mainWindow(of: appElement) else {
        throw NSError(domain: "DashboardResizeUISmoke", code: 8, userInfo: [
            NSLocalizedDescriptionKey: "Dictator-md main window did not become accessible"
        ])
    }

    try verifySidebarVisible(in: window, width: 1200, height: 820)
    try verifySidebarVisible(in: window, width: 760, height: 540)
    try verifySidebarVisible(in: window, width: 1100, height: 720)
    try verifySidebarVisible(in: window, width: 760, height: 540)
    print("Dashboard resize UI smoke test passed.")
} catch {
    fputs("Dashboard resize UI smoke test failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}
