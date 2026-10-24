import AppKit
import Foundation

// No windows, keys, microphone, clipboard writes or input-source changes.
@main
enum KeyboardThreadingSmoke {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let primed = CommandLine.arguments.contains("--primed")
        let expected = primed ? TextInjector.pasteKeyCode() : nil
        DispatchQueue.global().asyncAfter(deadline: .now() + 20) {
            fputs("FAIL keyboard lookup deadlocked\n", stderr)
            exit(1)
        }
        Task.detached {
            var first: CGKeyCode?
            for index in 0..<200 {
                guard let key = TextInjector.pasteKeyCode() else {
                    fputs("FAIL current keyboard layout has no paste key\n", stderr)
                    exit(1)
                }
                if index == 0 { first = key }
                guard key == first, expected == nil || key == expected else {
                    fputs("FAIL inconsistent keyboard resolution\n", stderr)
                    exit(1)
                }
                await Task.yield()
            }
            let reference = first!
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<8 {
                    group.addTask {
                        for _ in 0..<50 { precondition(TextInjector.pasteKeyCode() == reference) }
                    }
                }
            }
            await MainActor.run {
                precondition(TextInjector.pasteKeyCode() == reference)
                let count = NSPasteboard.general.changeCount
                let rejected = TextInjector().insertWithDelivery(text: "Do not paste this")
                precondition(rejected.reason == "invalidExecutionContext" && !rejected.outcome.wasSent)
                precondition(NSPasteboard.general.changeCount == count)
            }
            print("PASS 600 detached/concurrent keyboard lookups (\(primed ? "main-thread primed" : "cold start")), main-thread lookup and deadlock guard, key=\(reference)")
            exit(0)
        }
        app.run()
    }
}
