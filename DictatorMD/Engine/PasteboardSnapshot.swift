import AppKit

/// Copies each available pasteboard representation, not just plain text.
struct PasteboardSnapshot {
    private let pasteboard: NSPasteboard
    private let items: [[(NSPasteboard.PasteboardType, Data)]]

    init(pasteboard: NSPasteboard) {
        self.pasteboard = pasteboard
        items = (pasteboard.pasteboardItems ?? []).map { item in
            item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            }
        }
    }

    func restoreIfUnchanged(expectedChangeCount: Int, after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard pasteboard.changeCount == expectedChangeCount else { return }
            pasteboard.clearContents()
            let restoredItems = items.map { contents -> NSPasteboardItem in
                let item = NSPasteboardItem()
                for (type, data) in contents { item.setData(data, forType: type) }
                return item
            }
            if !restoredItems.isEmpty { pasteboard.writeObjects(restoredItems) }
        }
    }
}
