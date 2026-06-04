import Foundation

enum AppPaths {
    static let appSupportName = "Dictator-md"
    private static let legacyAppSupportNames = [
        "DictatorMD",
        ["Whisper", "Dictation"].joined()
    ]

    static func supportDirectory() -> URL {
        let root = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
        let current = root.appendingPathComponent(appSupportName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: current.path) {
            for legacyName in legacyAppSupportNames {
                let legacy = root.appendingPathComponent(legacyName, isDirectory: true)
                if FileManager.default.fileExists(atPath: legacy.path) {
                    try? FileManager.default.copyItem(at: legacy, to: current)
                    break
                }
            }
        }

        try? FileManager.default.createDirectory(at: current, withIntermediateDirectories: true)
        return current
    }

    static func supportSubdirectory(_ name: String) -> URL {
        let directory = supportDirectory().appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
