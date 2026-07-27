#!/usr/bin/env swift

import AppKit
import ApplicationServices
import Foundation

let sourceURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("DictatorMD/UI/FloatingNodeView.swift")
let source = try String(contentsOf: sourceURL, encoding: .utf8)
guard source.contains("panel.level = .popUpMenu"),
      source.contains(".fullScreenAuxiliary"),
      source.contains("NSWorkspace.activeSpaceDidChangeNotification"),
      source.contains("panel?.orderFrontRegardless()") else {
    fputs("Floating node is not configured to stay over full-screen app spaces.\n", stderr)
    exit(1)
}

let bundleIdentifier = "com.dictatormd.DictatorMD"
let applications = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)

guard let application = applications.first else {
    fputs("Dictator-md is not running.\n", stderr)
    exit(1)
}

let appElement = AXUIElementCreateApplication(application.processIdentifier)
var windowsValue: CFTypeRef?
guard AXUIElementCopyAttributeValue(
    appElement,
    kAXWindowsAttribute as CFString,
    &windowsValue
) == .success,
let windows = windowsValue as? [AXUIElement],
let nodeWindow = windows.first(where: { window in
    var titleValue: CFTypeRef?
    guard AXUIElementCopyAttributeValue(
        window,
        kAXTitleAttribute as CFString,
        &titleValue
    ) == .success else {
        return false
    }
    return titleValue as? String == "Dictator-md Floating Node"
}) else {
    fputs("Floating node window is not accessible.\n", stderr)
    exit(1)
}

var sizeValue: CFTypeRef?
guard AXUIElementCopyAttributeValue(
    nodeWindow,
    kAXSizeAttribute as CFString,
    &sizeValue
) == .success,
let sizeValue,
CFGetTypeID(sizeValue) == AXValueGetTypeID() else {
    fputs("Floating node size is unavailable.\n", stderr)
    exit(1)
}

let axSize = sizeValue as! AXValue
guard
AXValueGetType(axSize) == .cgSize else {
    fputs("Floating node size is unavailable.\n", stderr)
    exit(1)
}

var size = CGSize.zero
guard AXValueGetValue(axSize, .cgSize, &size) else {
    fputs("Floating node size could not be decoded.\n", stderr)
    exit(1)
}

guard size.width <= 92, size.height <= 12 else {
    fputs("Collapsed floating node captures too much screen space: \(Int(size.width))x\(Int(size.height)).\n", stderr)
    exit(1)
}

print("PASS collapsed floating node footprint \(Int(size.width))x\(Int(size.height))")
