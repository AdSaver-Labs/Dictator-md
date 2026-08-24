import AppKit
import Darwin

/// Keeps exactly one Dictator-md process in charge of the global hotkey and floating node.
final class SingleInstanceCoordinator {
    private var fileDescriptor: Int32 = -1

    init?() {
        let lockURL = AppPaths.supportDirectory().appendingPathComponent("dictator-md.lock")
        let descriptor = open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor != -1 else { return nil }

        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            return nil
        }

        fileDescriptor = descriptor
    }

    deinit {
        guard fileDescriptor != -1 else { return }
        flock(fileDescriptor, LOCK_UN)
        close(fileDescriptor)
    }

    static func activateExistingInstance() {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let existing = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.dictatormd.DictatorMD")
            .first { $0.processIdentifier != currentPID && !$0.isTerminated }

        existing?.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }
}
