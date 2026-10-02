import AppKit
import Foundation

@main
enum DictationFoundationsSmoke {
    static func main() {
        let gate = DictationOperationGate()
        precondition(gate.isActive)
        gate.cancel()
        precondition(!gate.isActive)

        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let first = NSPasteboardItem()
        first.setString("before", forType: .string)
        first.setData(Data("<b>before</b>".utf8), forType: .html)
        let second = NSPasteboardItem()
        let customType = NSPasteboard.PasteboardType("com.dictatormd.test")
        second.setData(Data([0, 1, 2, 3]), forType: customType)
        precondition(board.writeObjects([first, second]))

        let snapshot = PasteboardSnapshot(pasteboard: board)
        board.clearContents()
        board.setString("temporary dictation", forType: .string)
        snapshot.restoreIfUnchanged(expectedChangeCount: board.changeCount, after: 0)
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        precondition(board.pasteboardItems?.count == 2)
        precondition(board.pasteboardItems?[0].string(forType: .string) == "before")
        precondition(board.pasteboardItems?[0].data(forType: .html) == Data("<b>before</b>".utf8))
        precondition(board.pasteboardItems?[1].data(forType: customType) == Data([0, 1, 2, 3]))

        let secondSnapshot = PasteboardSnapshot(pasteboard: board)
        board.clearContents()
        board.setString("temporary dictation", forType: .string)
        secondSnapshot.restoreIfUnchanged(expectedChangeCount: board.changeCount, after: 0)
        board.clearContents()
        board.setString("new user copy", forType: .string)
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        precondition(board.string(forType: .string) == "new user copy")
        print("Dictation foundations smoke test passed.")
    }
}
