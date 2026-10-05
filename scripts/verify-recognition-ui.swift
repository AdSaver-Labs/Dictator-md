import AppKit
import ApplicationServices
import Foundation

func attribute(_ name: String, _ element: AXUIElement) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}
func descendants(_ root: AXUIElement) -> [AXUIElement] {
    var result = [root], index = 0
    while index < result.count {
        result += attribute(kAXChildrenAttribute, result[index]) as? [AXUIElement] ?? []
        index += 1
    }
    return result
}
func labels(_ element: AXUIElement) -> [String] {
    [kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute, kAXValueAttribute].compactMap { attribute($0, element) as? String }
}
func wait(_ condition: () -> Bool) -> Bool {
    let end = Date().addingTimeInterval(5)
    repeat {
        if condition() { return true }
        Thread.sleep(forTimeInterval: 0.1)
    } while Date() < end
    return false
}
func press(_ label: String, root: AXUIElement) -> Bool {
    guard let button = descendants(root).first(where: {
        attribute(kAXRoleAttribute, $0) as? String == kAXButtonRole && labels($0).contains(label)
    }) else { return false }
    return AXUIElementPerformAction(button, kAXPressAction as CFString) == .success
}
func fill(_ label: String, text: String, root: AXUIElement) -> Bool {
    guard let field = descendants(root).first(where: {
        attribute(kAXRoleAttribute, $0) as? String == kAXTextFieldRole && labels($0).contains(label)
    }) else { return false }
    AXUIElementSetAttributeValue(field, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    guard AXUIElementSetAttributeValue(field, kAXValueAttribute as CFString, text as CFString) == .success else { return false }
    // Commit the editor value as a user would by moving to the next control.
    for down in [true, false] {
        CGEvent(keyboardEventSource: nil, virtualKey: 48, keyDown: down)?.post(tap: .cghidEventTap)
    }
    return true
}
func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}

require(AXIsProcessTrusted(), "Accessibility is needed for the UI test host")
guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.dictatormd.DictatorMD").first else { fatalError("Installed app is not running") }
app.activate(options: [.activateAllWindows])
let root = AXUIElementCreateApplication(app.processIdentifier)
guard let window = (attribute(kAXWindowsAttribute, root) as? [AXUIElement])?.first(where: { labels($0).contains("Dictator-md") }) else { fatalError("Open the app's main window first") }
let originalSize = attribute(kAXSizeAttribute, window)
defer {
    if let originalSize { AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, originalSize) }
}
let phrase = "dictatormd ui smoke phrase"
let spelling = "DictatorSmokeSpelling"
let storeURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Dictator-md/corrections.json")
func persisted() -> Bool {
    guard let data = try? Data(contentsOf: storeURL), let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return false }
    return entries.contains { $0["heard"] as? String == phrase }
}
require(!persisted(), "A previous UI smoke correction already exists")
for size in [CGSize(width: 900, height: 700), CGSize(width: 1400, height: 900)] {
    var size = size
    if let value = AXValueCreate(.cgSize, &size) { AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value) }
    require(press("Open Vocabulary", root: window), "Vocabulary navigation failed")
    require(wait { descendants(window).contains { labels($0).contains("Recognized phrase") } }, "Correction editor missing")
    print("PASS correction editor present at \(Int(size.width))x\(Int(size.height))")
}
require(fill("Recognized phrase", text: phrase, root: window), "Recognized phrase field is not editable")
require(fill("Correct spelling", text: spelling, root: window), "Spelling field is not editable")
Thread.sleep(forTimeInterval: 0.3)
require(press("Save Correction", root: window), "Save button is not clickable")
require(wait { persisted() }, "UI did not persist correction")
require(wait { press("Delete correction", root: window) }, "Delete button is not clickable")
require(wait { !persisted() }, "UI did not delete correction")
require(press("Open History", root: window), "History navigation failed")
require(wait { press("Save a spelling correction", root: window) }, "History correction button is not clickable")
require(wait { descendants(root).contains { labels($0).contains("Save a Correction") } }, "History correction sheet did not open")
require(press("Close", root: root), "Correction sheet close failed")
print("PASS UI save/delete, local persistence and History correction sheet")
