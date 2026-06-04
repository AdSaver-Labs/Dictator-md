import Foundation

final class DebugLog {
    static let shared = DebugLog()

    private let queue = DispatchQueue(label: "com.dictatormd.debuglog")
    private let fileURL: URL

    private init() {
        let directory = AppPaths.supportSubdirectory("Logs")
        fileURL = directory.appendingPathComponent("debug.log")
    }

    var path: String {
        fileURL.path
    }

    func log(_ message: String) {
        queue.async {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let line = "[\(timestamp)] \(message)\n"
            guard let data = line.data(using: .utf8) else { return }

            if FileManager.default.fileExists(atPath: self.fileURL.path),
               let handle = try? FileHandle(forWritingTo: self.fileURL) {
                try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
                try? handle.close()
            } else {
                try? data.write(to: self.fileURL, options: .atomic)
            }
        }
    }

    func clear() {
        queue.async {
            try? "".write(to: self.fileURL, atomically: true, encoding: .utf8)
        }
    }
}
