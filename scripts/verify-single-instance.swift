import Foundation

let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let source = try String(contentsOf: root.appendingPathComponent("DictatorMD/App/DictatorMDApp.swift"))
let coordinator = try String(contentsOf: root.appendingPathComponent("DictatorMD/Utilities/SingleInstanceCoordinator.swift"))

let checks = [
    source.contains("SingleInstanceCoordinator()"),
    source.contains("activateExistingInstance"),
    coordinator.contains("flock(descriptor, LOCK_EX | LOCK_NB)"),
    coordinator.contains("runningApplications(withBundleIdentifier: \"com.dictatormd.DictatorMD\")")
]

guard checks.allSatisfy({ $0 }) else {
    fputs("Single-instance contract failed.\n", stderr)
    exit(1)
}

print("Single-instance contract passed.")
