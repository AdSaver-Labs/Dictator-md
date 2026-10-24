import AppKit
import Foundation
import Carbon.HIToolbox

// A disposable external AppKit editor exercises the production injector, not a mock.
#if !ENGINE_PIPELINE_TESTING
@main
#endif
struct LiveInsertionTest {
    static func main() {
        let app = NSApplication.shared
        if CommandLine.arguments.contains("--delivery-contracts") {
            do { try checkDeliveryContracts(); exit(0) }
            catch { fputs("Delivery contract failed: \(error)\n", stderr); exit(1) }
        }
        if CommandLine.arguments.contains("--keyboard-layouts") {
            do { try checkKeyboardLayouts(); exit(0) }
            catch { fputs("Keyboard layout check failed: \(error)\n", stderr); exit(1) }
        }
        if CommandLine.arguments.contains("--fixture") {
            app.setActivationPolicy(.regular)
            let fixture = EditorFixture(directory: URL(fileURLWithPath: CommandLine.arguments.last!))
            fixture.start()
            withExtendedLifetime(fixture) { app.run() }
        } else {
            app.setActivationPolicy(.accessory)
            guard AXIsProcessTrusted() else {
                fputs("Live insertion requires Accessibility access for the invoking terminal/agent.\n", stderr)
                exit(2)
            }
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    if CommandLine.arguments.contains("--fixture-capabilities") {
                        try checkFixtureCapabilities()
                    } else if CommandLine.arguments.contains("--surface-check") {
                        try runSurfaceCheck()
                    } else if CommandLine.arguments.contains("--browser-check") {
                        try runBrowserCheck()
                    } else {
                        try runTests()
                    }
                    exit(0)
                } catch {
                    fputs("Live insertion FAILED: \(error)\n", stderr)
                    exit(1)
                }
            }
            app.run()
        }
    }

    static func checkKeyboardLayouts() throws {
        let expectations: [(String, CGKeyCode?)] = [
            ("com.apple.keylayout.US", 9),
            ("com.apple.keylayout.Dvorak", 47),
            ("com.apple.keylayout.French", nil),
            ("com.apple.keylayout.Bulgarian", nil),
            ("com.apple.keylayout.Bulgarian-Phonetic", nil)
        ]
        for (id, expected) in expectations {
            let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
            let sources = TISCreateInputSourceList(filter, true).takeRetainedValue() as! [TISInputSource]
            guard let source = sources.first,
                  let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
                throw Failure("Missing system keyboard fixture: \(id)")
            }
            let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
            guard let key = TextInjector.pasteKeyCode(layoutData: data), expected == nil || key == expected else {
                throw Failure("Paste key did not resolve for \(id)")
            }
            print("PASS \(id) Command-V physical key=\(key)")
        }
        print("Five keyboard layouts verified without changing the user's input source.")
    }

    static func checkDeliveryContracts() throws {
        guard !TextInjector.confirmedChange(before: "hello old", after: "hello unrelated", selection: CFRange(location: 6, length: 3), insertedText: "hello"),
              TextInjector.confirmedChange(before: "🙂 AFTER tail", after: "🙂 БГ tail", selection: CFRange(location: 3, length: 5), insertedText: "БГ"),
              !TextInjector.confirmedChange(before: "hello", after: "hello hello", selection: nil, insertedText: "hello"),
              !TextInjector.confirmedChange(before: "hello", after: "hello!", selection: CFRange(location: Int.max, length: 1), insertedText: "!"),
              !TextInjector.confirmedChange(before: "hello", after: "hello!", selection: CFRange(location: -1, length: 1), insertedText: "!"),
              !TextInjector.confirmedChange(before: nil, after: "hello", selection: CFRange(location: 0, length: 0), insertedText: "hello"),
              TextInjector.confirmedChange(before: "", after: "hello", selection: CFRange(location: 0, length: 0), insertedText: "hello") else {
            throw Failure("exact UTF-16 readback verification failed")
        }
        print("PASS seven exact readback contracts: replacement, UTF-16, missing values and invalid ranges")
    }

    static func runSurfaceCheck() throws {
        let hermes = CommandLine.arguments.contains("hermes")
        let bundle = hermes ? "com.nousresearch.hermes" : "com.google.Chrome"
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundle }) else {
            throw Failure("The requested test application is not running")
        }
        app.activate()
        let activationDeadline = Date().addingTimeInterval(1.25)
        while NSWorkspace.shared.frontmostApplication?.processIdentifier != app.processIdentifier && Date() < activationDeadline {
            Thread.sleep(forTimeInterval: 0.025)
        }
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else {
            throw Failure("The test application could not become frontmost")
        }
        var captured: InsertionTarget?
        DispatchQueue.main.sync { captured = FocusTracker.shared.currentInsertionTarget() }
        guard let target = captured, let field = target.focusedElement else {
            throw Failure("No field was captured")
        }
        func attribute(_ name: String, of element: AXUIElement = field) -> String? {
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
            return value as? String
        }
        let before = (attribute(kAXValueAttribute) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let role = attribute(kAXRoleAttribute)
        let description = attribute(kAXDescriptionAttribute) ?? ""
        let title = target.focusedWindow.flatMap { attribute(kAXTitleAttribute, of: $0) } ?? ""
        if hermes {
            guard role == kAXTextAreaRole, description == "Message",
                  ["", "What should we tackle?", "Add more context", "Give Hermes a task"].contains(before) else {
                throw Failure("Refusing to modify a non-empty/non-composer Hermes field")
            }
        } else {
            guard role == kAXTextFieldRole, description == "Address and search bar",
                  title.lowercased().contains("new tab"),
                  ["", "dictatormd-disposable-probe"].contains(before) else {
                throw Failure("Refusing to modify anything but an empty New Tab address bar")
            }
        }
        let clipboard = PasteboardSnapshot(pasteboard: .general)
        defer { clipboard.restoreIfUnchanged(expectedChangeCount: NSPasteboard.general.changeCount, after: 0) }
        print("Captured \(bundle) role=\(role ?? "nil") window=\(target.focusedWindow != nil) anchor=\(target.clickAnchor != nil). Move focus elsewhere, then send Return to the test process. No message will be submitted.")
        fflush(stdout)
        _ = readLine()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dictatormd-surface-\(UUID())")
        var processes: [Process] = []
        var other: FixtureClient?
        defer {
            for process in processes where process.isRunning { process.terminate() }
            try? FileManager.default.removeItem(at: root)
        }
        if CommandLine.arguments.contains("--switch-app") {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            other = try launchFixture(at: root, processes: &processes)
            _ = try other!.command("focusOriginal")
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == other!.pid else {
                throw Failure("External fixture did not acquire real foreground focus")
            }
        }
        let probe = "Dictator surface check Sofia Благоевград 123"
        let outcome = TextInjector().insert(text: probe, target: target)
        let delivered = attribute(kAXValueAttribute) ?? ""
        guard outcome.wasSent, delivered.contains(probe), delivered.components(separatedBy: probe).count == 2 else {
            throw Failure("\(bundle) actual delivery failed: outcome=\(outcome) window=\(target.focusedWindow != nil) anchor=\(target.clickAnchor != nil)")
        }
        if let other, try other.command("snapshot")["original"] != "Before AFTER tail" {
            throw Failure("The transcript went into the newer application's field")
        }
        print("PASS \(bundle): actual original field contains probe exactly once (\(outcome)). Remove the disposable probe before continuing.")
        fflush(stdout)
        Thread.sleep(forTimeInterval: 2.5)
    }

    static func runBrowserCheck() throws {
        guard let browser = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.google.Chrome" }) else {
            throw Failure("Chrome is not running")
        }
        browser.activate()
        Thread.sleep(forTimeInterval: 0.25)
        var captured: InsertionTarget?
        DispatchQueue.main.sync { captured = FocusTracker.shared.currentInsertionTarget() }
        guard let target = captured, target.bundleIdentifier == "com.google.Chrome" else {
            throw Failure("focus the disposable Chrome field first")
        }
        var title: CFTypeRef?
        guard let window = target.focusedWindow,
              AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &title) == .success,
              (title as? String)?.contains("Disposable Browser Insertion Test") == true else {
            throw Failure("refusing to insert into a non-test browser window")
        }
        print("Browser target captured field=\(target.focusedElement != nil) range=\(target.selectedTextRange != nil) anchor=\(target.clickAnchor != nil). Change focus, then send Return to this test process.")
        fflush(stdout)
        _ = readLine()
        let text = "Browser delivery check: Sofia, Благоевград, 123"
        let outcome = TextInjector().insert(text: text, target: target)
        var delivered: CFTypeRef?
        guard outcome == .confirmed, let field = target.focusedElement,
              AXUIElementCopyAttributeValue(field, kAXValueAttribute as CFString, &delivered) == .success,
              let value = delivered as? String, value.contains(text),
              value.components(separatedBy: text).count == 2 else {
            throw Failure("browser insertion failed actual original-field readback")
        }
        print("PASS browser original-field readback: \(outcome), probe appears exactly once. Verify the other field is unchanged.")
        fflush(stdout)
        // Keep the main loop alive for production clipboard restoration.
        Thread.sleep(forTimeInterval: 2.5)
    }

    static func runTests() throws {
        try checkFixtureCapabilities()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dictatormd-live-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let originalClipboard = PasteboardSnapshot(pasteboard: .general)
        let previousApp = NSWorkspace.shared.frontmostApplication
        var processes = [Process]()
        defer {
            for process in processes where process.isRunning { process.terminate() }
            originalClipboard.restoreIfUnchanged(expectedChangeCount: NSPasteboard.general.changeCount, after: 0)
            Thread.sleep(forTimeInterval: 0.1)
            previousApp?.activate()
            try? FileManager.default.removeItem(at: root)
        }
        let first = try launchFixture(at: root.appendingPathComponent("first"), processes: &processes)
        let second = try launchFixture(at: root.appendingPathComponent("second"), processes: &processes)
        let injector = TextInjector()

        func capture(mode: String? = nil) throws -> InsertionTarget {
            _ = try first.command("reset")
            if let mode { _ = try first.command(mode) }
            _ = try first.command("focusOriginal")
            var target: InsertionTarget?
            DispatchQueue.main.sync { target = FocusTracker.shared.currentInsertionTarget() }
            guard let target, target.app?.processIdentifier == first.pid,
                  target.focusedElement != nil, target.focusedWindow != nil else {
                throw Failure("fixture AX capture missing field/window")
            }
            return target
        }
        func assertInserted(_ text: String, outcome: InsertionOutcome, label: String, replacesSelection: Bool = true) throws {
            let state = try first.command("snapshot")
            let other = try second.command("snapshot")
            guard outcome.wasSent, state["original"]?.contains(text) == true,
                  state["other"] == "Other field", state["otherWindow"] == "Other window",
                  other["original"] == "Before AFTER tail" else {
                // Only disposable fixture text is printed, never user editor data.
                throw Failure("\(label): outcome=\(outcome); first=\(state) second=\(other)")
            }
            guard state["original"]!.components(separatedBy: text).count == 2 else {
                throw Failure("\(label): duplicated insertion")
            }
            if replacesSelection && state["original"] != "Before \(text) tail" {
                throw Failure("\(label): original selection/caret was not restored")
            }
            print("PASS \(label) (\(outcome))")
        }

        var target = try capture()
        try assertInserted("English live paste", outcome: injector.insert(text: "English live paste", target: target), label: "native AX insertion")

        target = try capture()
        _ = try first.command("focusOther")
        try assertInserted("Original field only", outcome: injector.insert(text: "Original field only", target: target), label: "restore after another field in same window")

        target = try capture()
        _ = try first.command("focusOtherWindow")
        try assertInserted("Original window only", outcome: injector.insert(text: "Original window only", target: target), label: "restore after another window of same app")

        target = try capture()
        _ = try second.command("focusOriginal")
        try assertInserted("Returned from other app", outcome: injector.insert(text: "Returned from other app", target: target), label: "restore after switching application")

        // Hide the AX field to exercise the same click/clipboard path as custom editors.
        func pointTarget(_ source: InsertionTarget) throws -> InsertionTarget {
            guard let app = source.app, let frame = source.fieldFrame else { throw Failure("missing field geometry") }
            let anchor = ClickAnchor(app: app, screenPoint: CGPoint(x: frame.midX, y: frame.midY), capturedAt: Date().addingTimeInterval(-900))
            return InsertionTarget(app: app, focusedElement: nil, focusedWindow: source.focusedWindow,
                                   selectedTextRange: nil, clickAnchor: anchor, windowFrame: source.windowFrame)
        }
        target = try pointTarget(capture())
        _ = try second.command("focusOriginal")
        DispatchQueue.main.sync { FocusTracker.shared.recordMouseDown(screenPoint: CGPoint(x: 40, y: 40)) }
        try assertInserted("Frozen destination paste", outcome: injector.insert(text: "Frozen destination paste", target: target), label: "clipboard paste after newer click and long processing", replacesSelection: false)
        guard NSPasteboard.general.string(forType: .string) == "Frozen destination paste" else {
            throw Failure("unverified paste did not retain clipboard recovery")
        }

        target = try pointTarget(capture())
        _ = try first.command("moveOriginal")
        _ = try second.command("focusOriginal")
        let bulgarian = String(repeating: "Благоевград и София: надеждна диктовка 123. ", count: 60).trimmingCharacters(in: .whitespaces)
        // Production app adds one trailing space after punctuation.
        try assertInserted(bulgarian, outcome: injector.insert(text: bulgarian, target: target), label: "long Bulgarian clipboard paste into moved original window", replacesSelection: false)

        target = try pointTarget(capture())
        _ = try first.command("resizeOriginal")
        let resized = injector.insert(text: "Resize recovery", target: target)
        guard resized == .failed, try first.command("snapshot")["original"] == "Before AFTER tail",
              NSPasteboard.general.string(forType: .string) == "Resize recovery" else {
            throw Failure("changed geometry must not click an unknown location")
        }
        print("PASS resized point-only target refuses guessing and preserves clipboard")

        target = try capture()
        let cancelled = injector.insert(text: "Must not appear", target: target, shouldProceed: { false })
        guard cancelled == .failed, try first.command("snapshot")["original"] == "Before AFTER tail" else {
            throw Failure("cancelled operation inserted text")
        }
        print("PASS cancellation before insertion")

        let missing = InsertionTarget(app: nil, focusedElement: nil, focusedWindow: nil, selectedTextRange: nil, clickAnchor: nil)
        let failed = injector.insert(text: "Recover this transcript", target: missing)
        guard failed == .failed, NSPasteboard.general.string(forType: .string) == "Recover this transcript" else {
            throw Failure("failed insertion lost clipboard recovery")
        }
        print("PASS failed destination retains transcript on clipboard")

        var gateChecks = 0
        _ = injector.insert(text: "Do not overwrite a new copy", target: missing, shouldProceed: {
            gateChecks += 1
            if gateChecks == 2 {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("New user copy", forType: .string)
            }
            return true
        })
        guard NSPasteboard.general.string(forType: .string) == "New user copy" else {
            throw Failure("recovery overwrote a newer clipboard copy")
        }
        print("PASS failure recovery preserves newer user clipboard content")

        target = try capture()
        _ = try first.command("changeDraft")
        let changed = injector.insertWithDelivery(text: "Must not replace new draft", target: target)
        guard changed.outcome == .failed, changed.reason == "draftChanged",
              try first.command("snapshot")["original"] == "A completely new draft" else {
            throw Failure("changed draft was overwritten")
        }
        print("PASS changed draft is preserved with an actionable delivery reason")

        target = try capture()
        _ = try first.command("rejectSelection")
        let selectionFailure = injector.insertWithDelivery(text: "Wrong caret", target: target)
        guard selectionFailure.outcome == .failed, selectionFailure.reason == "selectionChanged",
              try first.command("snapshot")["original"] == "Before AFTER tail" else {
            throw Failure("failed selection restoration must not insert at the wrong caret")
        }
        print("PASS refused selection restoration leaves destination unchanged")

        target = try capture(mode: "delayAX")
        try assertInserted("Delayed edit", outcome: injector.insert(text: "Delayed edit", target: target), label: "delayed AX acknowledgement readback")

        target = try capture(mode: "clipboardOnly")
        var canWriteText = DarwinBoolean(true)
        guard let field = target.focusedElement,
              AXUIElementIsAttributeSettable(field, kAXSelectedTextAttribute as CFString, &canWriteText) == .success,
              !canWriteText.boolValue else { throw Failure("clipboard fixture must advertise read-only AX text") }
        let clipboardEdit = injector.insertWithDelivery(text: "Clipboard exact edit", target: target)
        guard clipboardEdit.strategy == "clipboard" else { throw Failure("fixture did not exercise the clipboard path") }
        try assertInserted("Clipboard exact edit", outcome: clipboardEdit.outcome, label: "clipboard exact selection replacement")

        target = try capture(mode: "copyDuringPaste")
        let copyResult = injector.insertWithDelivery(text: "Keep the new copy", target: target)
        guard copyResult.strategy == "clipboard" else { throw Failure("copy-during-paste fixture bypassed the clipboard path") }
        try assertInserted("Keep the new copy", outcome: copyResult.outcome, label: "new user copy during receiver paste")
        guard copyResult.outcome == .confirmed else { throw Failure("clipboard readback was not confirmed") }
        Thread.sleep(forTimeInterval: 2.25)
        guard NSPasteboard.general.string(forType: .string) == "New copy during paste" else {
            throw Failure("clipboard restoration erased a newer user copy")
        }
        print("PASS clipboard ownership remains tied to the original write")

        target = try capture()
        _ = try first.command("closeOriginal")
        _ = try second.command("focusOriginal")
        let closed = injector.insertWithDelivery(text: "Closed window recovery", target: target)
        guard closed.outcome == .failed, try first.command("snapshot")["original"] == "Before AFTER tail",
              try second.command("snapshot")["original"] == "Before AFTER tail" else {
            throw Failure("closed target received or redirected text")
        }
        print("PASS closed original window is not silently retargeted")

        _ = try first.command("focusSecure")
        var secure: InsertionTarget?
        DispatchQueue.main.sync { secure = FocusTracker.shared.currentInsertionTarget() }
        guard secure?.isSecure == true, secure?.valueAtCapture == nil else { throw Failure("secure field was not excluded during capture") }
        let secureResult = injector.insertWithDelivery(text: "Not a password", target: secure)
        guard secureResult.reason == "secureField", secureResult.outcome == .failed,
              try first.command("snapshot")["secure"] == "" else { throw Failure("secure field received text") }
        print("PASS secure fields are excluded without reading their contents")

        try checkDeliveryContracts()
        print("All 19 live insertion checks passed using the production TextInjector.")
    }

    // Validate the fixture through the same remote AX API without activating
    // a window, touching focus, posting keys or changing the user's clipboard.
    static func checkFixtureCapabilities() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dictatormd-capabilities-\(UUID())")
        var processes = [Process]()
        defer {
            for process in processes where process.isRunning { process.terminate() }
            try? FileManager.default.removeItem(at: root)
        }
        let fixture = try launchFixture(at: root, processes: &processes)
        _ = try fixture.command("showWithoutFocus")
        func originalField(_ element: AXUIElement, depth: Int = 0) -> AXUIElement? {
            guard depth < 8 else { return nil }
            var identifier: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &identifier)
            if identifier as? String == "dictatormd-original" { return element }
            var children: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
            for child in children as? [AXUIElement] ?? [] {
                if let field = originalField(child, depth: depth + 1) { return field }
            }
            return nil
        }
        for mode in ["reset", "clipboardOnly", "copyDuringPaste"] {
            _ = try fixture.command(mode)
            guard let field = originalField(AXUIElementCreateApplication(fixture.pid)) else {
                throw Failure("offscreen fixture field unavailable")
            }
            var writable = DarwinBoolean(false)
            let result = AXUIElementIsAttributeSettable(field, kAXSelectedTextAttribute as CFString, &writable)
            guard result == .success, writable.boolValue == (mode == "reset") else {
                throw Failure("fixture mode=\(mode) AX writable=\(writable.boolValue) status=\(result.rawValue)")
            }
            print("PASS remote fixture capability \(mode): writable=\(writable.boolValue)")
        }
    }

    struct Failure: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }

    struct FixtureClient {
        let directory: URL
        let pid: pid_t

        func command(_ action: String) throws -> [String: String] {
            let id = UUID().uuidString
            let request = ["id": id, "action": action]
            let data = try JSONEncoder().encode(request)
            try data.write(to: directory.appendingPathComponent("request.json"), options: .atomic)
            let response = directory.appendingPathComponent("response.json")
            let deadline = Date().addingTimeInterval(5)
            repeat {
                if let data = try? Data(contentsOf: response),
                   let result = try? JSONDecoder().decode([String: String].self, from: data), result["id"] == id {
                    Thread.sleep(forTimeInterval: 0.20)
                    return result
                }
                Thread.sleep(forTimeInterval: 0.04)
            } while Date() < deadline
            throw Failure("fixture command timed out: \(action)")
        }
    }

    static func launchFixture(at directory: URL, processes: inout [Process]) throws -> FixtureClient {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        process.arguments = ["--fixture", directory.path]
        try process.run()
        processes.append(process)
        let client = FixtureClient(directory: directory, pid: process.processIdentifier)
        _ = try client.command("reset")
        return client
    }
}

final class EditorFixture {
    let directory: URL
    var windows = [NSWindow]()
    var fields = [FixtureTextView]()
    let secureField = NSSecureTextField(frame: NSRect(x: 20, y: 120, width: 400, height: 24))
    var timer: Timer?
    var lastRequest = ""

    init(directory: URL) { self.directory = directory }

    func start() {
        let menu = NSMenu()
        let edit = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.submenu = editMenu
        menu.addItem(edit)
        NSApp.mainMenu = menu
        for index in 0..<2 {
            let window = NSWindow(contentRect: NSRect(x: 80 + index * 40, y: 260, width: 600, height: 300),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Dictator-md disposable insertion test \(index)"
            window.isReleasedWhenClosed = false
            let count = index == 0 ? 2 : 1
            for number in 0..<count {
                let view = FixtureTextView(frame: NSRect(x: 20, y: 20 + number * 130, width: 550, height: 100))
                view.isRichText = false
                view.font = .systemFont(ofSize: 16)
                if index == 0 && number == 0 { view.setAccessibilityIdentifier("dictatormd-original") }
                window.contentView!.addSubview(view)
                fields.append(view)
            }
            windows.append(window)
        }
        windows[1].contentView!.addSubview(secureField)
        timer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in self?.receive() }
    }

    func receive() {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("request.json")),
              let command = try? JSONDecoder().decode([String: String].self, from: data),
              let id = command["id"], id != lastRequest else { return }
        lastRequest = id
        switch command["action"] {
        case "reset":
            if fields[0] is DelayedFixtureTextView { replaceOriginal(delayed: false) }
            fields.forEach { $0.mode = "normal" }
            fields[0].string = "Before AFTER tail"
            fields[1].string = "Other field"
            fields[2].string = "Other window"
        case "focusOriginal": focus(field: 0, window: 0)
        case "focusOther": focus(field: 1, window: 0)
        case "focusOtherWindow": focus(field: 2, window: 1)
        case "moveOriginal": windows[0].setFrameOrigin(NSPoint(x: 140, y: 300))
        case "resizeOriginal": windows[0].setContentSize(NSSize(width: 680, height: 330))
        case "changeDraft": fields[0].string = "A completely new draft"
        case "rejectSelection":
            fields[0].setSelectedRange(NSRange(location: 0, length: 0))
            fields[0].mode = "rejectSelection"
        case "delayAX": replaceOriginal(delayed: true)
        case "clipboardOnly": fields[0].mode = "clipboardOnly"
        case "copyDuringPaste": fields[0].mode = "copyDuringPaste"
        case "closeOriginal": windows[0].close()
        case "showWithoutFocus":
            windows[0].setFrameOrigin(NSPoint(x: -10000, y: -10000))
            windows[0].orderBack(nil)
        case "focusSecure":
            NSApp.activate(ignoringOtherApps: true)
            windows[1].makeKeyAndOrderFront(nil)
            windows[1].makeFirstResponder(secureField)
        default: break
        }
        let result = ["id": id, "original": fields[0].string, "other": fields[1].string, "otherWindow": fields[2].string, "secure": secureField.stringValue]
        if let data = try? JSONEncoder().encode(result) {
            try? data.write(to: directory.appendingPathComponent("response.json"), options: .atomic)
        }
    }

    func focus(field: Int, window: Int) {
        NSApp.activate(ignoringOtherApps: true)
        windows[window].makeKeyAndOrderFront(nil)
        windows[window].makeFirstResponder(fields[field])
        fields[field].setSelectedRange(NSRange(location: field == 0 ? 7 : fields[field].string.utf16.count, length: field == 0 ? 5 : 0))
    }

    private func replaceOriginal(delayed: Bool) {
        let old = fields[0]
        let replacement = delayed ? DelayedFixtureTextView(frame: old.frame) : FixtureTextView(frame: old.frame)
        replacement.isRichText = false
        replacement.font = old.font
        replacement.string = old.string
        replacement.setAccessibilityIdentifier("dictatormd-original")
        old.removeFromSuperview()
        windows[0].contentView!.addSubview(replacement)
        fields[0] = replacement
    }
}

class FixtureTextView: NSTextView {
    var mode = "normal" {
        didSet { isEditable = !isClipboardOnly }
    }
    private var isClipboardOnly: Bool { ["clipboardOnly", "copyDuringPaste"].contains(mode) }

    override func setAccessibilitySelectedTextRange(_ range: NSRange) {
        if mode != "rejectSelection" { super.setAccessibilitySelectedTextRange(range) }
    }

    override func paste(_ sender: Any?) {
        // Model editors that expose read-only AX text but accept Paste through
        // their own editing command. AppKit must report the real AX capability.
        let wasEditable = isEditable
        isEditable = true
        super.paste(sender)
        isEditable = wasEditable
        if mode == "copyDuringPaste" {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("New copy during paste", forType: .string)
        }
    }

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if isClipboardOnly, item.action == #selector(paste(_:)) { return true }
        return super.validateUserInterfaceItem(item)
    }
}

// Overriding the modern setter makes AppKit advertise it as writable even for
// noneditable views. Keep this override out of the clipboard-only fixture class.
final class DelayedFixtureTextView: FixtureTextView {
    override func setAccessibilitySelectedText(_ text: String?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { super.setAccessibilitySelectedText(text) }
    }
}
