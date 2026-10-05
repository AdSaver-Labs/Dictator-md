import Foundation

let sourceURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("DictatorMD/Engine/TextInjector.swift")
let source = try String(contentsOf: sourceURL, encoding: .utf8)

let requiredCompatibilityBundles = [
    "com.apple.MobileSMS",
    "com.google.Chrome",
    "com.lemon.lvoverseas",
    "com.nousresearch.hermes"
]

let missing = requiredCompatibilityBundles.filter { !source.contains("\"\($0)\"") }
guard missing.isEmpty,
      source.contains("keepTranscriptOnClipboard"),
      source.contains("restoreClickAnchorIfNeeded") else {
    fputs("Insertion compatibility contract failed: missing \(missing.joined(separator: ", "))\n", stderr)
    exit(1)
}

print("Insertion compatibility contract passed for Messages, Chrome, CapCut, and Hermes.")
