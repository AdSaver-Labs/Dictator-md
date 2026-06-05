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

    func insert(text: String, target: InsertionTarget? = nil) {
        let prepared = prepareForInsertion(text)
        guard !prepared.isEmpty else { return }
        DebugLog.shared.log("[TextInjector] insert length=\(prepared.count) target=\(target?.appName ?? "nil") bundle=\(target?.bundleIdentifier ?? "nil") hasElement=\(target?.focusedElement != nil)")

        typingQueue.sync {
            restoreTargetIfNeeded(target)
            if !AXIsProcessTrusted() {
                DebugLog.shared.log("[TextInjector] AX not trusted; trying clipboard paste fallback")
                if pasteWithClipboard(text: prepared) {
                    return
                }
                DebugLog.shared.log("[TextInjector] AX clipboard paste failed; using direct unicode typing fallback")
                typeUnicode(text: prepared)
                return
            }
            if !pasteWithClipboard(text: prepared) {
                DebugLog.shared.log("[TextInjector] clipboardPaste failed; falling back to unicode")
                typeUnicode(text: prepared)
            }
        }
    }

    func insert(text: String, targetApp: NSRunningApplication? = nil) {
        insert(
            text: text,
            target: InsertionTarget(app: targetApp, focusedElement: nil, selectedTextRange: nil)
        )
    }

    private func restoreTargetIfNeeded(_ target: InsertionTarget?) {
        let targetApp = target?.app
        guard let targetApp,
              targetApp.bundleIdentifier != Bundle.main.bundleIdentifier,
              !targetApp.isTerminated else {
            DebugLog.shared.log("[TextInjector] activationSkipped target=\(targetApp?.localizedName ?? "nil")")
            return
        }

        targetApp.activate(options: [.activateIgnoringOtherApps])
        DebugLog.shared.log("[TextInjector] activateTarget name=\(targetApp.localizedName ?? "nil") pid=\(targetApp.processIdentifier)")
        Thread.sleep(forTimeInterval: 0.10)

        guard let focusedElement = target?.focusedElement else { return }

        let appElement = AXUIElementCreateApplication(targetApp.processIdentifier)
        let focusResult = AXUIElementSetAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            focusedElement
        )
        let selectedRangeResult = restoreSelectedTextRange(target?.selectedTextRange, on: focusedElement)
        DebugLog.shared.log("[TextInjector] restoreFocus result=\(focusResult.rawValue) selectedRange=\(selectedRangeResult.map(String.init) ?? "nil")")
        Thread.sleep(forTimeInterval: 0.06)
    }

    private func prepareForInsertion(_ text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if let last = trimmed.last, ".!?。！？".contains(last) {
            trimmed += " "
        }
        return trimmed
    }

    private func pasteWithClipboard(text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)

        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            DebugLog.shared.log("[TextInjector] pasteboardSetString failed")
            snapshot.restoreIfUnchanged(expectedChangeCount: pasteboard.changeCount, after: clipboardRestoreDelay)
            return false
        }

        Thread.sleep(forTimeInterval: 0.035)

        guard postPasteShortcut() else {
            DebugLog.shared.log("[TextInjector] postPasteShortcut failed")
            snapshot.restoreIfUnchanged(expectedChangeCount: pasteboard.changeCount, after: clipboardRestoreDelay)
            return false
        }

        DebugLog.shared.log("[TextInjector] postPasteShortcut ok")
        snapshot.restoreIfUnchanged(expectedChangeCount: pasteboard.changeCount, after: clipboardRestoreDelay)
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
        keyUp.post(tap: .cghidEventTap)
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
