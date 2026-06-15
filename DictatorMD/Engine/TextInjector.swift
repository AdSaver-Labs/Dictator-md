import AppKit
import CoreGraphics
import Foundation

final class TextInjector {
    private let source: CGEventSource?
    private let typingQueue = DispatchQueue(label: "com.DictatorMD.typing", qos: .userInteractive)
    private let clipboardRestoreDelay: TimeInterval = 2.0

    init() {
        source = CGEventSource(stateID: .hidSystemState)
    }

    @discardableResult
    func insert(text: String, target: InsertionTarget? = nil) -> Bool {
        let prepared = prepareForInsertion(text)
        guard !prepared.isEmpty else { return false }
        DebugLog.shared.log("[TextInjector] insert length=\(prepared.count) target=\(target?.appName ?? "nil") bundle=\(target?.bundleIdentifier ?? "nil") hasElement=\(target?.focusedElement != nil)")

        return typingQueue.sync {
            let restoredTarget = restoreTargetIfNeeded(target)
            if !AXIsProcessTrusted() {
                DebugLog.shared.log("[TextInjector] AX not trusted; trying clipboard paste fallback")
                if restoredTarget, pasteWithClipboard(text: prepared) {
                    return true
                }
                DebugLog.shared.log("[TextInjector] AX clipboard paste failed; using direct unicode typing fallback")
                typeUnicode(text: prepared)
                return true
            }

            if !requiresClipboardPaste(target), insertDirectlyWithAccessibility(text: prepared, target: target) {
                return true
            }

            if pasteWithClipboardRetry(text: prepared, target: target) {
                return true
            }

            DebugLog.shared.log("[TextInjector] clipboardPaste failed after retries; falling back to unicode")
            if restoreTargetIfNeeded(target), target?.focusedElement != nil {
                typeUnicode(text: prepared)
                return true
            }

            DebugLog.shared.log("[TextInjector] no focused target for unicode fallback; leaving transcript on clipboard")
            putOnClipboard(text: prepared)
            return false
        }
    }

    @discardableResult
    func insert(text: String, targetApp: NSRunningApplication? = nil) -> Bool {
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
            return targetApp == nil
        }

        if isAppFrontmost(targetApp) {
            DebugLog.shared.log("[TextInjector] activationSkipped alreadyFrontmost target=\(targetApp.localizedName ?? "nil")")
            if let focusedElement = target?.focusedElement {
                _ = setFocused(true, on: focusedElement)
                _ = restoreSelectedTextRange(target?.selectedTextRange, on: focusedElement)
            }
            return true
        }

        targetApp.activate(options: [.activateAllWindows])
        if let bundleURL = targetApp.bundleURL {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { _, error in
                if let error {
                    DebugLog.shared.log("[TextInjector] openApplication activation error=\(error.localizedDescription)")
                }
            }
        }
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
            let restored = waitUntilFrontmost(targetApp, timeout: 1.25)
            DebugLog.shared.log("[TextInjector] restoreTarget frontmost=\(restored) current=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil")")
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
        return restored
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

        guard postMouseClick(at: anchor.screenPoint) else {
            DebugLog.shared.log("[TextInjector] clickAnchor clickFailed point=\(Int(anchor.screenPoint.x)),\(Int(anchor.screenPoint.y))")
            return false
        }

        DebugLog.shared.log("[TextInjector] clickAnchor restored point=\(Int(anchor.screenPoint.x)),\(Int(anchor.screenPoint.y))")
        Thread.sleep(forTimeInterval: 0.16)
        return true
    }

    private func insertDirectlyWithAccessibility(text: String, target: InsertionTarget?) -> Bool {
        guard let element = target?.focusedElement else {
            DebugLog.shared.log("[TextInjector] directAX skipped noFocusedElement")
            return false
        }

        if let focusedWindow = target?.focusedWindow {
            AXUIElementPerformAction(focusedWindow, kAXRaiseAction as CFString)
        }

        _ = setFocused(true, on: element)
        _ = restoreSelectedTextRange(target?.selectedTextRange, on: element)
        let result = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFString
        )

        if result == .success {
            DebugLog.shared.log("[TextInjector] directAX selectedText ok")
            return true
        }

        DebugLog.shared.log("[TextInjector] directAX selectedText failed result=\(result.rawValue)")
        return false
    }

    private func prepareForInsertion(_ text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if let last = trimmed.last, ".!?。！？".contains(last) {
            trimmed += " "
        }
        return trimmed
    }

    private func pasteWithClipboardRetry(text: String, target: InsertionTarget?) -> Bool {
        let delays: [TimeInterval] = [0.05, 0.14, 0.28]
        for (index, delay) in delays.enumerated() {
            let targetIsFrontmost: Bool
            if index > 0 {
                DebugLog.shared.log("[TextInjector] retryPaste attempt=\(index + 1)")
                targetIsFrontmost = restoreTargetIfNeeded(target)
            } else {
                targetIsFrontmost = isTargetFrontmost(target)
            }
            guard targetIsFrontmost else {
                DebugLog.shared.log("[TextInjector] pasteSkipped targetNotFrontmost target=\(target?.appName ?? "nil") current=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil")")
                continue
            }
            Thread.sleep(forTimeInterval: delay)
            guard restoreClickAnchorIfNeeded(target) else {
                continue
            }
            if pasteWithClipboard(text: text, restoreClipboard: index == delays.count - 1) {
                return true
            }
        }
        putOnClipboard(text: text)
        return false
    }

    private func requiresClipboardPaste(_ target: InsertionTarget?) -> Bool {
        switch target?.bundleIdentifier {
        case "com.viber.osx":
            DebugLog.shared.log("[TextInjector] compatibility clipboardPreferred bundle=com.viber.osx")
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

        if target.focusedElement == nil {
            return true
        }

        switch target.bundleIdentifier {
        case "com.viber.osx",
             "com.google.Chrome",
             "com.google.Chrome.canary",
             "com.brave.Browser",
             "com.microsoft.edgemac",
             "com.apple.Safari",
             "org.mozilla.firefox",
             "company.thebrowser.Browser":
            return true
        default:
            return false
        }
    }

    private func pasteWithClipboard(text: String) -> Bool {
        pasteWithClipboard(text: text, restoreClipboard: true)
    }

    private func pasteWithClipboard(text: String, restoreClipboard: Bool) -> Bool {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)

        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            DebugLog.shared.log("[TextInjector] pasteboardSetString failed")
            if restoreClipboard {
                snapshot.restoreIfUnchanged(expectedChangeCount: pasteboard.changeCount, after: clipboardRestoreDelay)
            }
            return false
        }

        Thread.sleep(forTimeInterval: 0.055)

        guard postPasteShortcut() else {
            DebugLog.shared.log("[TextInjector] postPasteShortcut failed")
            if restoreClipboard {
                snapshot.restoreIfUnchanged(expectedChangeCount: pasteboard.changeCount, after: clipboardRestoreDelay)
            }
            return false
        }

        DebugLog.shared.log("[TextInjector] postPasteShortcut ok")
        if restoreClipboard {
            snapshot.restoreIfUnchanged(expectedChangeCount: pasteboard.changeCount, after: clipboardRestoreDelay)
        }
        return true
    }

    private func putOnClipboard(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if pasteboard.setString(text, forType: .string) {
            DebugLog.shared.log("[TextInjector] clipboardFallback stored")
        } else {
            DebugLog.shared.log("[TextInjector] clipboardFallback failed")
        }
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

    private func isTargetFrontmost(_ target: InsertionTarget?) -> Bool {
        guard let targetApp = target?.app else { return true }
        return isAppFrontmost(targetApp)
    }

    private func isAppFrontmost(_ targetApp: NSRunningApplication) -> Bool {
        let frontmost = NSWorkspace.shared.frontmostApplication
        return frontmost?.processIdentifier == targetApp.processIdentifier
            || frontmost?.bundleIdentifier == targetApp.bundleIdentifier
    }

    private func waitUntilFrontmost(_ targetApp: NSRunningApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let frontmost = NSWorkspace.shared.frontmostApplication
            if frontmost?.processIdentifier == targetApp.processIdentifier
                || frontmost?.bundleIdentifier == targetApp.bundleIdentifier {
                return true
            }
            Thread.sleep(forTimeInterval: 0.05)
        } while Date() < deadline
        return false
    }

    private func typeUnicode(text: String) {
        let utf16 = Array(text.utf16)
        let chunkSize = 16
        var offset = 0

        while offset < utf16.count {
            let end = min(offset + chunkSize, utf16.count)
            let chunk = Array(utf16[offset..<end])

            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
                offset = end
                continue
            }

            chunk.withUnsafeBufferPointer { ptr in
                keyDown.keyboardSetUnicodeString(stringLength: Int(chunk.count), unicodeString: ptr.baseAddress)
                keyUp.keyboardSetUnicodeString(stringLength: Int(chunk.count), unicodeString: ptr.baseAddress)
            }

            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)

            offset = end

            if offset < utf16.count {
                Thread.sleep(forTimeInterval: 0.005)
            }
        }
    }
}

private struct PasteboardSnapshot {
    let string: String?

    init(pasteboard: NSPasteboard) {
        string = pasteboard.string(forType: .string)
    }

    func restoreIfUnchanged(expectedChangeCount: Int, after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let pasteboard = NSPasteboard.general
            guard pasteboard.changeCount == expectedChangeCount else { return }
            pasteboard.clearContents()
            if let string {
                pasteboard.setString(string, forType: .string)
            }
        }
    }
}
