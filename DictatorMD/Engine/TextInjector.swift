import AppKit
import CoreGraphics
import Foundation

enum InsertionOutcome {
    case confirmed
    case sentUnverified
    case failed

    var wasSent: Bool { self != .failed }
}

final class TextInjector {
    private let source: CGEventSource?
    private let typingQueue = DispatchQueue(label: "com.DictatorMD.typing", qos: .userInteractive)
    private let clipboardRestoreDelay: TimeInterval = 2.0

    init() {
        source = CGEventSource(stateID: .hidSystemState)
    }

    func insert(text: String, target: InsertionTarget? = nil, shouldProceed: () -> Bool = { true }) -> InsertionOutcome {
        let prepared = prepareForInsertion(text)
        guard !prepared.isEmpty, shouldProceed() else { return .failed }
        DebugLog.shared.log("[TextInjector] insert length=\(prepared.count) target=\(target?.appName ?? "nil") bundle=\(target?.bundleIdentifier ?? "nil") hasElement=\(target?.focusedElement != nil)")

        return typingQueue.sync {
            let clipboardAtStart = NSPasteboard.general.changeCount
            var outcome = InsertionOutcome.failed
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
                return .failed
            }
            guard shouldProceed(), restoreTargetIfNeeded(target) else {
                DebugLog.shared.log("[TextInjector] destinationRestore failed")
                return .failed
            }

            if !requiresClipboardPaste(target),
               let directResult = insertDirectlyWithAccessibility(text: prepared, target: target, shouldProceed: shouldProceed) {
                outcome = directResult
                return outcome
            }

            if shouldProceed(), restoreClickAnchorIfNeeded(target), verifyTargetFocus(target) {
                let pasteResult = pasteWithClipboard(text: prepared, target: target, restoreClipboard: shouldRestoreClipboardAfterDictation, shouldProceed: shouldProceed)
                if pasteResult.wasSent {
                    outcome = pasteResult
                    return outcome
                }
            }

            if let element = target?.focusedElement, shouldProceed(), verifyTargetFocus(target) {
                let before = readableValue(of: element)
                if typeUnicode(text: prepared, shouldProceed: shouldProceed, target: target) {
                    outcome = confirmedChange(before: before, after: readableValue(of: element), insertedText: prepared)
                        ? .confirmed : .sentUnverified
                    return outcome
                }
            }

            DebugLog.shared.log("[TextInjector] no verified target for insertion; transcript remains in history")
            return .failed
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
            return target.clickAnchor != nil && target.focusedWindow != nil
        }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFEqual(expected, focused) else { return false }
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

        if let focusedWindow = target?.focusedWindow {
            AXUIElementPerformAction(focusedWindow, kAXRaiseAction as CFString)
        }

        _ = setFocused(true, on: element)
        _ = restoreSelectedTextRange(target?.selectedTextRange, on: element)
        guard shouldProceed(), verifyTargetFocus(target) else { return nil }
        let before = readableValue(of: element)
        let result = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFString
        )

        if result == .success {
            DebugLog.shared.log("[TextInjector] directAX selectedText ok")
            return confirmedChange(before: before, after: readableValue(of: element), insertedText: text)
                ? .confirmed : .sentUnverified
        }

        DebugLog.shared.log("[TextInjector] directAX selectedText failed result=\(result.rawValue)")
        return nil
    }

    private func readableValue(of element: AXUIElement?) -> String? {
        guard let element else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func confirmedChange(before: String?, after: String?, insertedText: String) -> Bool {
        guard let before, let after else { return false }
        return after != before && after.contains(insertedText.trimmingCharacters(in: .whitespacesAndNewlines))
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
    ) -> InsertionOutcome {
        guard shouldProceed(), verifyTargetFocus(target) else { return .failed }
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)
        let before = readableValue(of: target?.focusedElement)

        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            DebugLog.shared.log("[TextInjector] pasteboardSetString failed")
            snapshot.restoreIfUnchanged(expectedChangeCount: pasteboard.changeCount, after: 0)
            return .failed
        }

        Thread.sleep(forTimeInterval: 0.055)

        guard shouldProceed(), verifyTargetFocus(target), postPasteShortcut() else {
            DebugLog.shared.log("[TextInjector] paste cancelled or target changed before shortcut")
            if !shouldProceed() {
                snapshot.restoreIfUnchanged(expectedChangeCount: pasteboard.changeCount, after: 0)
            }
            return .failed
        }

        // Let the receiving application's event loop consume paste before readback.
        var confirmed = false
        let deadline = Date().addingTimeInterval(before == nil ? 0.20 : 0.80)
        repeat {
            Thread.sleep(forTimeInterval: 0.04)
            confirmed = confirmedChange(before: before, after: readableValue(of: target?.focusedElement), insertedText: text)
            if confirmed { break }
        } while Date() < deadline
        DebugLog.shared.log("[TextInjector] postPasteShortcut sent confirmed=\(confirmed)")
        // Keep unverified delivery recoverable; never retry a posted paste blindly.
        if restoreClipboard && confirmed {
            snapshot.restoreIfUnchanged(expectedChangeCount: pasteboard.changeCount, after: clipboardRestoreDelay)
        }
        return confirmed ? .confirmed : .sentUnverified
    }

    private func postPasteShortcut() -> Bool {
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.012)
        keyUp.post(tap: .cghidEventTap)
        return true
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

    private func typeUnicode(text: String, shouldProceed: () -> Bool, target: InsertionTarget?) -> Bool {
        let utf16 = Array(text.utf16)
        let chunkSize = 16
        var offset = 0
        var sentAny = false

        while offset < utf16.count {
            guard shouldProceed(), verifyTargetFocus(target) else { return sentAny }
            let end = min(offset + chunkSize, utf16.count)
            let chunk = Array(utf16[offset..<end])

            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
                return sentAny
            }

            chunk.withUnsafeBufferPointer { ptr in
                keyDown.keyboardSetUnicodeString(stringLength: Int(chunk.count), unicodeString: ptr.baseAddress)
                keyUp.keyboardSetUnicodeString(stringLength: Int(chunk.count), unicodeString: ptr.baseAddress)
            }

            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
            sentAny = true

            offset = end

            if offset < utf16.count {
                Thread.sleep(forTimeInterval: 0.005)
            }
        }
        return sentAny
    }
}
