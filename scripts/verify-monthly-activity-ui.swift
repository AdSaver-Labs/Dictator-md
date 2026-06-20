#!/usr/bin/env swift

import AppKit
import ApplicationServices
import Foundation

private let bundleIdentifier = "com.dictatormd.DictatorMD"
private let appURL = URL(fileURLWithPath: "/Applications/Dictator-md.app")

private func attribute(_ name: String, of element: AXUIElement) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
        return nil
    }
    return value
}

private func stringAttribute(_ name: String, of element: AXUIElement) -> String? {
    attribute(name, of: element) as? String
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

private func waitUntil(
    timeout: TimeInterval,
    pollInterval: TimeInterval = 0.1,
    condition: () -> Bool
) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
        if condition() { return true }
        Thread.sleep(forTimeInterval: pollInterval)
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
        throw NSError(domain: "DictatorMDUISmoke", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Timed out launching Dictator-md"
        ])
    }
    if let launchError { throw launchError }
    guard let launchedApp else {
        throw NSError(domain: "DictatorMDUISmoke", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "Dictator-md did not return a running application"
        ])
    }
    return launchedApp
}

private func mainWindow(of appElement: AXUIElement) -> AXUIElement? {
    let windows = attribute(kAXWindowsAttribute, of: appElement) as? [AXUIElement] ?? []
    return windows.first {
        stringAttribute(kAXTitleAttribute, of: $0) == "Dictator-md"
    }
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

private func verifyMonthlyMetrics(in window: AXUIElement, width: Int, height: Int) throws {
    setWindow(window, width: CGFloat(width), height: CGFloat(height))
    Thread.sleep(forTimeInterval: 0.5)

    guard pressButton(label: "Activity range: This month", in: window) else {
        throw NSError(domain: "DictatorMDUISmoke", code: 3, userInfo: [
            NSLocalizedDescriptionKey: "The This month activity filter is missing or not pressable"
        ])
    }
    Thread.sleep(forTimeInterval: 0.7)

    let visibleLabels = descendants(of: window).flatMap(labels)
    let captureRows = visibleLabels.filter { $0.hasPrefix("CAP ") }
    let wpmRows = visibleLabels.filter { $0.hasPrefix("WPM ") }
    let truncatedRows = (captureRows + wpmRows).filter {
        $0.contains("…") || $0.contains("...")
    }

    guard captureRows.count >= 28 else {
        throw NSError(domain: "DictatorMDUISmoke", code: 4, userInfo: [
            NSLocalizedDescriptionKey: "Expected monthly CAP rows at \(width)x\(height), found \(captureRows.count)"
        ])
    }
    guard wpmRows.count >= 28 else {
        throw NSError(domain: "DictatorMDUISmoke", code: 5, userInfo: [
            NSLocalizedDescriptionKey: "Expected monthly WPM rows at \(width)x\(height), found \(wpmRows.count)"
        ])
    }
    guard truncatedRows.isEmpty else {
        throw NSError(domain: "DictatorMDUISmoke", code: 6, userInfo: [
            NSLocalizedDescriptionKey: "Truncated monthly metrics at \(width)x\(height): \(truncatedRows)"
        ])
    }

    print("PASS \(width)x\(height) CAP=\(captureRows.count) WPM=\(wpmRows.count)")
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
        throw NSError(domain: "DictatorMDUISmoke", code: 7, userInfo: [
            NSLocalizedDescriptionKey: "Dictator-md main window did not become accessible"
        ])
    }

    try verifyMonthlyMetrics(in: window, width: 1400, height: 900)
    try verifyMonthlyMetrics(in: window, width: 900, height: 700)
    print("Monthly activity UI smoke test passed.")
} catch {
    fputs("Monthly activity UI smoke test failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}
