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
            guard AXIsProcessTrusted() else {
                DebugLog.shared.log("[TextInjector] AX not trusted; cannot verify destination")
                return .failed
            }
            guard shouldProceed(), restoreTargetIfNeeded(target) else { return .failed }

            if !requiresClipboardPaste(target),
               let directResult = insertDirectlyWithAccessibility(text: prepared, target: target, shouldProceed: shouldProceed) {
                return directResult
            }

            if shouldProceed(), verifyTargetFocus(target), restoreClickAnchorIfNeeded(target) {
                let pasteResult = pasteWithClipboard(text: prepared, target: target, restoreClipboard: shouldRestoreClipboardAfterDictation, shouldProceed: shouldProceed)
                if pasteResult.wasSent { return pasteResult }
            }

            if let element = target?.focusedElement, shouldProceed(), verifyTargetFocus(target) {
                let before = readableValue(of: element)
                if typeUnicode(text: prepared, shouldProceed: shouldProceed, target: target) {
                    return confirmedChange(before: before, after: readableValue(of: element), insertedText: prepared)
                        ? .confirmed : .sentUnverified
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
              targetApp.bundleIdentifier != Bundle.main.bundleIdentifier,
              !targetApp.isTerminated else {
            DebugLog.shared.log("[TextInjector] activationSkipped target=\(targetApp?.localizedName ?? "nil")")
            return false
        }

        if isAppFrontmost(targetApp) {
            DebugLog.shared.log("[TextInjector] activationSkipped alreadyFrontmost target=\(targetApp.localizedName ?? "nil")")
            if let focusedElement = target?.focusedElement {
                _ = setFocused(true, on: focusedElement)
                _ = restoreSelectedTextRange(target?.selectedTextRange, on: focusedElement)
            }
            return verifyTargetFocus(target)
        }

        targetApp.activate(options: [.activateAllWindows])
        DebugLog.shared.log("[TextInjector] activateTarget name=\(targetApp.localizedName ?? "nil") pid=\(targetApp.processIdentifier)")
        Thread.sleep(forTimeInterval: 0.20)

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
            let restored = waitUntilFrontmost(targetApp, timeout: 1.25) && verifyTargetFocus(target)
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
        return restored && verifyTargetFocus(target)
    }

    private func verifyTargetFocus(_ target: InsertionTarget?) -> Bool {
        guard let target, let app = target.app, isAppFrontmost(app), !app.isTerminated else { return false }
        guard let expected = target.focusedElement else {
            guard target.clickAnchor.map(FocusTracker.shared.isCurrentClickAnchor) == true,
                  let window = target.focusedWindow else { return false }
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            var currentWindow: CFTypeRef?
            return AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &currentWindow) == .success
                && currentWindow.map { CFEqual(window, $0) } == true
        }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFEqual(expected, focused) else { return false }
        if let window = target.focusedWindow {
            var currentWindow: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &currentWindow) == .success,
                  let currentWindow, CFEqual(window, currentWindow) else { return false }
        }
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

        guard FocusTracker.shared.isCurrentClickAnchor(anchor), postMouseClick(at: anchor.screenPoint) else {
            DebugLog.shared.log("[TextInjector] clickAnchor clickFailed point=\(Int(anchor.screenPoint.x)),\(Int(anchor.screenPoint.y))")
            return false
        }

        DebugLog.shared.log("[TextInjector] clickAnchor restored point=\(Int(anchor.screenPoint.x)),\(Int(anchor.screenPoint.y))")
        Thread.sleep(forTimeInterval: 0.16)
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
        return after != before && after.contains(insertedText)
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
             "com.apple.MobileSMS",
             "com.lemon.lvoverseas",
             "com.google.Chrome",
             "com.google.Chrome.canary",
             "com.brave.Browser",
             "com.microsoft.edgemac",
             "com.apple.Safari",
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
        return target.focusedElement == nil
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
            snapshot.restoreIfUnchanged(expectedChangeCount: pasteboard.changeCount, after: 0)
            return .failed
        }

        Thread.sleep(forTimeInterval: 0.12)
        let confirmed = confirmedChange(before: before, after: readableValue(of: target?.focusedElement), insertedText: text)
        DebugLog.shared.log("[TextInjector] postPasteShortcut sent confirmed=\(confirmed)")
        if restoreClipboard {
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
