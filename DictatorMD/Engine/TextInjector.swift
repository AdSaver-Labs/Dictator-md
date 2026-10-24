import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Foundation

final class TextInjector {
    private let source: CGEventSource?
    private let typingQueue = DispatchQueue(label: "com.DictatorMD.typing", qos: .userInteractive)
    private let clipboardRestoreDelay: TimeInterval = 2.0

    init() {
        source = CGEventSource(stateID: .hidSystemState)
    }

    func insert(text: String, target: InsertionTarget? = nil, shouldProceed: () -> Bool = { true }) -> InsertionOutcome {
        insertWithDelivery(text: text, target: target, shouldProceed: shouldProceed).outcome
    }

    func insertWithDelivery(text: String, target: InsertionTarget? = nil, shouldProceed: () -> Bool = { true }) -> InsertionDelivery {
        let started = ProcessInfo.processInfo.systemUptime
        let prepared = prepareForInsertion(text)
        guard !prepared.isEmpty, shouldProceed() else {
            return InsertionDelivery(outcome: .failed, strategy: "none", reason: "cancelled", durationMilliseconds: 0)
        }
        DebugLog.shared.log("[TextInjector] insert length=\(prepared.count) target=\(target?.appName ?? "nil") bundle=\(target?.bundleIdentifier ?? "nil") hasElement=\(target?.focusedElement != nil)")

        return typingQueue.sync {
            let clipboardAtStart = NSPasteboard.general.changeCount
            var outcome = InsertionOutcome.failed
            var strategy = "none"
            func finish(_ result: InsertionOutcome, _ reason: String) -> InsertionDelivery {
                outcome = result
                let delivery = InsertionDelivery(outcome: result, strategy: strategy, reason: reason,
                    durationMilliseconds: Int((ProcessInfo.processInfo.systemUptime - started) * 1000))
                DebugLog.shared.log("[TextInjector] delivery outcome=\(result.rawValue) strategy=\(strategy) reason=\(reason) ms=\(delivery.durationMilliseconds)")
                return delivery
            }
            defer {
                if outcome != .confirmed, shouldProceed(),
                   NSPasteboard.general.changeCount == clipboardAtStart {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(prepared, forType: .string)
                    DebugLog.shared.log("[TextInjector] clipboardRecovery stored outcome=\(outcome)")
                }
            }
            guard AXIsProcessTrusted() else {
                DebugLog.shared.log("[TextInjector] AX not trusted; cannot verify destination")
                return finish(.failed, "permissionMissing")
            }
            if let reason = destinationConflict(target, checkSelection: false) {
                return finish(.failed, reason)
            }
            guard shouldProceed(), restoreTargetIfNeeded(target) else {
                DebugLog.shared.log("[TextInjector] destinationRestore failed")
                return finish(.failed, shouldProceed() ? "destinationUnavailable" : "cancelled")
            }
            if let reason = destinationConflict(target, checkSelection: false) {
                return finish(.failed, reason)
            }

            strategy = "accessibility"
            if !requiresClipboardPaste(target),
               let directResult = insertDirectlyWithAccessibility(text: prepared, target: target, shouldProceed: shouldProceed) {
                return finish(directResult, directResult == .confirmed ? "verified" : "readbackUnavailable")
            }

            if shouldProceed(), restoreClickAnchorIfNeeded(target), verifyTargetFocus(target) {
                if let reason = destinationConflict(target, checkSelection: true) { return finish(.failed, reason) }
                strategy = "clipboard"
                let pasteResult = pasteWithClipboard(text: prepared, target: target, restoreClipboard: shouldRestoreClipboardAfterDictation, shouldProceed: shouldProceed)
                // Once clipboard delivery is attempted, preserve its result. A
                // new user copy or lost focus is not permission to type instead.
                return finish(pasteResult.outcome, pasteResult.reason)
            }

            DebugLog.shared.log("[TextInjector] no verified target for insertion; transcript remains in history")
            return finish(.failed, shouldProceed() ? "destinationUnavailable" : "cancelled")
        }
    }

    func insert(text: String, targetApp: NSRunningApplication? = nil) -> InsertionOutcome {
        insert(
            text: text,
            target: InsertionTarget(app: targetApp, focusedElement: nil, focusedWindow: nil, selectedTextRange: nil, clickAnchor: nil)
        )
    }

    @discardableResult
    private func restoreTargetIfNeeded(_ target: InsertionTarget?) -> Bool {
        let targetApp = target?.app
        guard let targetApp,
              targetApp.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              !targetApp.isTerminated else {
            DebugLog.shared.log("[TextInjector] activationSkipped target=\(targetApp?.localizedName ?? "nil")")
            return false
        }

        if !isAppFrontmost(targetApp) {
            targetApp.activate(options: [.activateAllWindows])
            DebugLog.shared.log("[TextInjector] activateTarget name=\(targetApp.localizedName ?? "nil") pid=\(targetApp.processIdentifier)")
            guard waitUntilFrontmost(targetApp, timeout: 1.25) else { return false }
        }

        // Restore the captured window even if another window of the same app is frontmost.
        if let focusedWindow = target?.focusedWindow {
            AXUIElementPerformAction(focusedWindow, kAXRaiseAction as CFString)
            let appElement = AXUIElementCreateApplication(targetApp.processIdentifier)
            let windowResult = AXUIElementSetAttributeValue(
                appElement,
                kAXFocusedWindowAttribute as CFString,
                focusedWindow
            )
            DebugLog.shared.log("[TextInjector] restoreWindow result=\(windowResult.rawValue)")
            Thread.sleep(forTimeInterval: 0.05)
        }

        guard let focusedElement = target?.focusedElement else {
            let restored = verifyTargetWindow(target) && target?.clickAnchor != nil
            DebugLog.shared.log("[TextInjector] clickAnchorOnly restore=\(restored)")
            return restored
        }

        let elementFocusResult = setFocused(true, on: focusedElement)
        let appElement = AXUIElementCreateApplication(targetApp.processIdentifier)
        let focusResult = AXUIElementSetAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            focusedElement
        )
        let selectedRangeResult = restoreSelectedTextRange(target?.selectedTextRange, on: focusedElement)
        DebugLog.shared.log("[TextInjector] restoreFocus element=\(elementFocusResult.map(String.init) ?? "nil") app=\(focusResult.rawValue) selectedRange=\(selectedRangeResult.map(String.init) ?? "nil")")
        Thread.sleep(forTimeInterval: 0.10)
        let restored = waitUntilFrontmost(targetApp, timeout: 1.25)
        DebugLog.shared.log("[TextInjector] restoreTarget frontmost=\(restored) current=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil")")
        // Custom editors may require a click before AX reports keyboard focus.
        return restored && verifyTargetWindow(target)
    }

    private func verifyTargetWindow(_ target: InsertionTarget?) -> Bool {
        guard let target, let app = target.app, isAppFrontmost(app), !app.isTerminated else { return false }
        guard let window = target.focusedWindow else { return target.focusedElement != nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var currentWindow: CFTypeRef?
        return AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &currentWindow) == .success
            && currentWindow.map { CFEqual(window, $0) } == true
    }

    private func verifyTargetFocus(_ target: InsertionTarget?) -> Bool {
        guard let target, let app = target.app, verifyTargetWindow(target) else { return false }
        guard let expected = target.focusedElement else {
            if let current = FocusTracker.focusedElement(in: app), FocusTracker.isSecureField(current) { return false }
            return target.clickAnchor != nil && target.focusedWindow != nil
        }
        guard let focused = FocusTracker.focusedElement(in: app), CFEqual(expected, focused) else { return false }
        return true
    }

    @discardableResult
    private func restoreClickAnchorIfNeeded(_ target: InsertionTarget?) -> Bool {
        guard shouldUseClickAnchor(target),
              let target,
              let anchor = target.clickAnchor else {
            return true
        }

        guard let targetApp = target.app,
              !targetApp.isTerminated else {
            DebugLog.shared.log("[TextInjector] clickAnchor skipped noTargetApp")
            return false
        }

        if !isAppFrontmost(targetApp) {
            targetApp.activate(options: [.activateAllWindows])
            DebugLog.shared.log("[TextInjector] clickAnchor activateTarget name=\(targetApp.localizedName ?? "nil")")
            guard waitUntilFrontmost(targetApp, timeout: 1.25) else {
                DebugLog.shared.log("[TextInjector] clickAnchor skipped notFrontmost current=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil")")
                return false
            }
            Thread.sleep(forTimeInterval: 0.12)
        }

        guard verifyTargetWindow(target),
              let capturedFrame = target.windowFrame,
              let currentFrame = target.focusedWindow.flatMap(FocusTracker.frame(of:)),
              abs(capturedFrame.width - currentFrame.width) < 2,
              abs(capturedFrame.height - currentFrame.height) < 2 else {
            DebugLog.shared.log("[TextInjector] clickAnchor skipped changedOrMissingWindowGeometry")
            return target.focusedElement != nil && verifyTargetFocus(target)
        }
        // This anchor belongs to this operation, not to the latest mouse click.
        let point = CGPoint(x: anchor.screenPoint.x + currentFrame.minX - capturedFrame.minX,
                            y: anchor.screenPoint.y + currentFrame.minY - capturedFrame.minY)
        guard currentFrame.contains(point), postMouseClick(at: point) else {
            DebugLog.shared.log("[TextInjector] clickAnchor clickFailed point=\(Int(anchor.screenPoint.x)),\(Int(anchor.screenPoint.y))")
            return false
        }

        DebugLog.shared.log("[TextInjector] clickAnchor restored point=\(Int(anchor.screenPoint.x)),\(Int(anchor.screenPoint.y))")
        Thread.sleep(forTimeInterval: 0.16)
        if let field = target.focusedElement {
            _ = restoreSelectedTextRange(target.selectedTextRange, on: field)
        }
        return true
    }

    private func insertDirectlyWithAccessibility(text: String, target: InsertionTarget?, shouldProceed: () -> Bool) -> InsertionOutcome? {
        guard let element = target?.focusedElement else {
            DebugLog.shared.log("[TextInjector] directAX skipped noFocusedElement")
            return nil
        }
        var canSetSelection = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &canSetSelection) == .success,
              canSetSelection.boolValue else { return nil }

        if let focusedWindow = target?.focusedWindow {
            AXUIElementPerformAction(focusedWindow, kAXRaiseAction as CFString)
        }

        _ = setFocused(true, on: element)
        _ = restoreSelectedTextRange(target?.selectedTextRange, on: element)
        guard shouldProceed(), verifyTargetFocus(target), destinationConflict(target, checkSelection: true) == nil else { return nil }
        let before = readableValue(of: element)
        let selection = FocusTracker.selectedTextRange(from: element)
        let result = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFString
        )

        if result == .success {
            DebugLog.shared.log("[TextInjector] directAX selectedText ok")
            return waitForReadback(before: before, selection: selection, element: element, insertedText: text)
                ? .confirmed : .sentUnverified
        }

        DebugLog.shared.log("[TextInjector] directAX selectedText failed result=\(result.rawValue)")
        // A timeout can mean the remote editor applied the edit without replying.
        // Never fall through and duplicate it with Cmd-V in that case.
        if result == .cannotComplete || readableValue(of: element) != before {
            return waitForReadback(before: before, selection: selection, element: element, insertedText: text)
                ? .confirmed : .sentUnverified
        }
        return nil
    }

    private func readableValue(of element: AXUIElement?) -> String? {
        guard let element else { return nil }
        return FocusTracker.readableValue(of: element)
    }

    static func confirmedChange(before: String?, after: String?, selection: CFRange?, insertedText: String) -> Bool {
        guard let before, let after, let selection, selection.location >= 0, selection.length >= 0 else { return false }
        let original = before as NSString
        guard selection.location <= original.length, selection.length <= original.length - selection.location else { return false }
        let expected = original.replacingCharacters(in: NSRange(location: selection.location, length: selection.length), with: insertedText)
        return Array(after.utf16) == Array(expected.utf16)
    }

    private func waitForReadback(before: String?, selection: CFRange?, element: AXUIElement?, insertedText: String) -> Bool {
        guard before != nil, selection != nil else { return false }
        let deadline = Date().addingTimeInterval(0.80)
        repeat {
            if Self.confirmedChange(before: before, after: readableValue(of: element), selection: selection, insertedText: insertedText) { return true }
            Thread.sleep(forTimeInterval: 0.04)
        } while Date() < deadline
        return false
    }

    private func destinationConflict(_ target: InsertionTarget?, checkSelection: Bool) -> String? {
        guard let target else { return "destinationUnavailable" }
        if target.isSecure { return "secureField" }
        guard let field = target.focusedElement else { return nil }
        var pid: pid_t = 0
        guard AXUIElementGetPid(field, &pid) == .success, pid == target.app?.processIdentifier else { return "destinationUnavailable" }
        if FocusTracker.isSecureField(field) { return "secureField" }
        if let captured = target.valueAtCapture {
            guard let current = readableValue(of: field), Array(current.utf16) == Array(captured.utf16) else { return "draftChanged" }
        }
        if checkSelection, let expected = target.selectedTextRange {
            guard let actual = FocusTracker.selectedTextRange(from: field),
                  actual.location == expected.location, actual.length == expected.length else { return "selectionChanged" }
        }
        return nil
    }

    private func prepareForInsertion(_ text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if let last = trimmed.last, ".!?。！？".contains(last) {
            trimmed += " "
        }
        return trimmed
    }

    private func requiresClipboardPaste(_ target: InsertionTarget?) -> Bool {
        switch target?.bundleIdentifier {
        case "com.viber.osx",
             "com.nousresearch.hermes",
             "com.apple.MobileSMS",
             "com.lemon.lvoverseas",
             "com.google.Chrome",
             "com.google.Chrome.canary",
             "com.brave.Browser",
             "com.microsoft.edgemac",
             "com.apple.Safari",
             "com.openai.codex",
             "notion.id",
             "com.tinyspeck.slackmacgap",
             "company.thebrowser.Browser",
             "org.mozilla.firefox":
            DebugLog.shared.log("[TextInjector] compatibility clipboardPreferred bundle=\(target?.bundleIdentifier ?? "nil")")
            return true
        default:
            return false
        }
    }

    private func shouldUseClickAnchor(_ target: InsertionTarget?) -> Bool {
        guard let target,
              target.clickAnchor != nil else {
            return false
        }
        // A clipboard-compatible editor still does not need a click if its
        // exact captured field already has keyboard focus. Clicking can open a
        // browser popup, collapse a selection or move the caret unnecessarily.
        return target.focusedElement == nil || !verifyTargetFocus(target)
    }

    private var shouldRestoreClipboardAfterDictation: Bool {
        !AppSettings.shared.keepTranscriptOnClipboard
    }

    private func pasteWithClipboard(
        text: String,
        target: InsertionTarget?,
        restoreClipboard: Bool,
        shouldProceed: () -> Bool
    ) -> (outcome: InsertionOutcome, reason: String) {
        guard shouldProceed(), verifyTargetFocus(target) else { return (.failed, "destinationUnavailable") }
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)
        let before = readableValue(of: target?.focusedElement)
        let selection = target?.focusedElement.flatMap(FocusTracker.selectedTextRange(from:))

        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            DebugLog.shared.log("[TextInjector] pasteboardSetString failed")
            snapshot.restoreIfUnchanged(expectedChangeCount: pasteboard.changeCount, after: 0)
            return (.failed, "clipboardUnavailable")
        }
        let ownedChangeCount = pasteboard.changeCount

        Thread.sleep(forTimeInterval: 0.055)

        guard pasteboard.changeCount == ownedChangeCount else { return (.failed, "clipboardChanged") }
        if let reason = destinationConflict(target, checkSelection: true) { return (.failed, reason) }
        guard shouldProceed(), pasteboard.changeCount == ownedChangeCount, verifyTargetFocus(target), postPasteShortcut() else {
            DebugLog.shared.log("[TextInjector] paste cancelled or target changed before shortcut")
            if !shouldProceed() {
                snapshot.restoreIfUnchanged(expectedChangeCount: ownedChangeCount, after: 0)
            }
            return (.failed, shouldProceed() ? "destinationUnavailable" : "cancelled")
        }

        // Let the receiving application's event loop consume paste before readback.
        let confirmed = waitForReadback(before: before, selection: selection, element: target?.focusedElement, insertedText: text)
        if before == nil { Thread.sleep(forTimeInterval: 0.20) }
        DebugLog.shared.log("[TextInjector] postPasteShortcut sent confirmed=\(confirmed)")
        // Keep unverified delivery recoverable; never retry a posted paste blindly.
        if restoreClipboard && confirmed {
            snapshot.restoreIfUnchanged(expectedChangeCount: ownedChangeCount, after: clipboardRestoreDelay)
        }
        return (confirmed ? .confirmed : .sentUnverified, confirmed ? "verified" : "readbackUnavailable")
    }

    private func postPasteShortcut() -> Bool {
        guard let key = Self.pasteKeyCode() else {
            DebugLog.shared.log("[TextInjector] no Paste key in current keyboard layout; clipboard recovery retained")
            return false
        }
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.012)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    static func pasteKeyCode() -> CGKeyCode? {
        func layout(_ source: TISInputSource?) -> Data? {
            guard let source, let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
            return Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        }
        // Input methods without layout data use the user's ASCII layout. Do not
        // fall back to a US physical key when a real non-US layout has no match.
        guard let data = layout(TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue())
            ?? layout(TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue()) else { return nil }
        return pasteKeyCode(layoutData: data)
    }

    static func pasteKeyCode(layoutData: Data) -> CGKeyCode? {
        layoutData.withUnsafeBytes { bytes in
            guard let address = bytes.baseAddress else { return nil }
            let keyboard = address.assumingMemoryBound(to: UCKeyboardLayout.self)
            for key: UInt16 in 0..<128 {
                var deadState: UInt32 = 0
                var length = 0
                var characters = [UniChar](repeating: 0, count: 8)
                let status = UCKeyTranslate(keyboard, key, UInt16(kUCKeyActionDown), UInt32(cmdKey >> 8),
                    UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                    &deadState, characters.count, &length, &characters)
                if status == noErr, length == 1, characters[0] == 0x76 { return key }
            }
            return nil
        }
    }

    private func postMouseClick(at point: CGPoint) -> Bool {
        guard let mouseDown = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseDown,
            mouseCursorPosition: point,
            mouseButton: .left
        ),
        let mouseUp = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseUp,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else {
            return false
        }

        mouseDown.setIntegerValueField(.eventSourceUserData, value: FocusTracker.syntheticClickMarker)
        mouseUp.setIntegerValueField(.eventSourceUserData, value: FocusTracker.syntheticClickMarker)
        mouseDown.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.018)
        mouseUp.post(tap: .cghidEventTap)
        return true
    }

    private func restoreSelectedTextRange(_ range: CFRange?, on element: AXUIElement) -> Int32? {
        guard var range else { return nil }
        guard let value = AXValueCreate(.cfRange, &range) else { return nil }
        let result = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            value
        )
        return result.rawValue
    }

    private func setFocused(_ focused: Bool, on element: AXUIElement) -> Int32? {
        let result = AXUIElementSetAttributeValue(
            element,
            kAXFocusedAttribute as CFString,
            focused as CFBoolean
        )
        return result.rawValue
    }

    private func isAppFrontmost(_ targetApp: NSRunningApplication) -> Bool {
        let frontmost = NSWorkspace.shared.frontmostApplication
        return frontmost?.processIdentifier == targetApp.processIdentifier
    }

    private func waitUntilFrontmost(_ targetApp: NSRunningApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let frontmost = NSWorkspace.shared.frontmostApplication
            if frontmost?.processIdentifier == targetApp.processIdentifier {
                return true
            }
            Thread.sleep(forTimeInterval: 0.05)
        } while Date() < deadline
        return false
    }

}
