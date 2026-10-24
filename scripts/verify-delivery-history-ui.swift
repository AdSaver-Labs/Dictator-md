import AppKit
import SwiftUI

// Render the production History row without launching the dictation engine,
// changing permissions, or adding test transcripts to the user's history.
@main
struct DeliveryHistoryPreview {
    static let originalClipboard = PasteboardSnapshot(pasteboard: .general)
    static let actions = PreviewActions()

    static func main() {
        _ = originalClipboard
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let menu = NSMenu()
        let appMenu = NSMenu()
        let quit = NSMenuItem(title: "Finish Verification", action: #selector(PreviewActions.finish), keyEquivalent: "q")
        quit.target = actions
        appMenu.addItem(quit)
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        menu.addItem(appItem)
        app.mainMenu = menu
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 640, height: 620),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "Disposable delivery History verification"
        window.isReleasedWhenClosed = false
        let examples: [(InsertionOutcome, String)] = [
            (.confirmed, "verified"), (.sentUnverified, "readbackUnavailable"), (.failed, "draftChanged")
        ]
        let rows = examples.map { outcome, reason in
            DictationHistoryItem(id: UUID(), timestamp: Date(), text: "Disposable delivery test. Благоевград и София.",
                language: "Bulgarian", appName: "Test editor", bundleIdentifier: "test.editor", audioDuration: 4,
                wordCount: 7, cleanupCutCount: 0,
                delivery: InsertionDelivery(outcome: outcome, strategy: "clipboard", reason: reason, durationMilliseconds: 425))
        }
        window.contentView = NSHostingView(rootView:
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(rows) { item in HistoryRow(item: item, colorScheme: .dark) }
                }.padding(16)
            }.preferredColorScheme(.dark)
        )
        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        withExtendedLifetime(window) { app.run() }
    }
}

final class PreviewActions: NSObject {
    @objc func finish() {
        // Only restore if the test's Copy button still owns the clipboard.
        if NSPasteboard.general.string(forType: .string) == "Disposable delivery test. Благоевград и София." {
            DeliveryHistoryPreview.originalClipboard.restoreIfUnchanged(expectedChangeCount: NSPasteboard.general.changeCount, after: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { NSApp.terminate(nil) }
    }
}
