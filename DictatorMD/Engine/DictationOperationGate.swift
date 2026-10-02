import Foundation

final class DictationOperationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }
}
