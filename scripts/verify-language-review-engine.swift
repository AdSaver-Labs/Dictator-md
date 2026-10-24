import AppKit
import AVFoundation
import Foundation

// Substitute only the storage root, so no test can write personal history.
enum AppPaths {
    static let root = FileManager.default.temporaryDirectory.appendingPathComponent("dictatormd-review-\(UUID())")
    static func supportDirectory() -> URL {
        try! FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
    static func supportSubdirectory(_ name: String) -> URL {
        let url = supportDirectory().appendingPathComponent(name)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

@main
enum LanguageReviewEngineSmoke {
    @MainActor static func main() async throws {
        guard CommandLine.arguments.count == 3 else { fatalError("Expected existing model and fixture directory") }
        defer { try? FileManager.default.removeItem(at: AppPaths.root) }
        _ = NSApplication.shared
        let previousSoundSetting = UserDefaults.standard.object(forKey: "soundFeedbackEnabled")
        defer {
            if let previousSoundSetting { UserDefaults.standard.set(previousSoundSetting, forKey: "soundFeedbackEnabled") }
            else { UserDefaults.standard.removeObject(forKey: "soundFeedbackEnabled") }
        }
        AppSettings.shared.soundFeedbackEnabled = false
        let bridge = try WhisperBridge(modelPath: CommandLine.arguments[1])
        let engine = DictationEngine(testBridge: bridge)
        precondition(!engine.shouldPresentReviewSheet(floatingNodeEnabled: true))
        precondition(!engine.shouldPresentReviewSheet(floatingNodeEnabled: false))
        let boardCount = NSPasteboard.general.changeCount
        let bg = try audio("12.caf")
        let en = try audio("13.caf")

        engine.testTranscribe([Float](repeating: 0, count: 16000), language: .auto, forcePreview: false)
        try await waitForPreview(engine)
        precondition(engine.languageReviewMessage?.contains("could not confidently") == true)
        precondition(engine.canRetryPreviewLanguage)
        precondition(engine.shouldPresentReviewSheet(floatingNodeEnabled: true))
        precondition(engine.shouldPresentReviewSheet(floatingNodeEnabled: false))
        engine.retryPreviewLanguage(.bulgarian)
        precondition(engine.state == .processing)
        precondition(!engine.shouldPresentReviewSheet(floatingNodeEnabled: true))
        engine.retryPreviewLanguage(.english) // Must be ignored while a retry runs.
        try await waitForPreview(engine)
        precondition(engine.canRetryPreviewLanguage)
        engine.discardPreview()
        precondition(engine.state == .idle && !engine.canRetryPreviewLanguage)

        engine.testTranscribe(bg, language: .bulgarian, forcePreview: true)
        try await waitForPreview(engine)
        precondition(engine.previewText.contains("български"))
        engine.testExpireReviewAudio()
        precondition(engine.shouldPresentReviewSheet(floatingNodeEnabled: true))
        let draft = engine.previewText
        engine.retryPreviewLanguage(.english)
        precondition(!engine.canRetryPreviewLanguage && engine.state == .preview && engine.previewText == draft)
        engine.cancelCurrentOperation()
        precondition(engine.state == .idle && !engine.canRetryPreviewLanguage && engine.previewText.isEmpty)

        engine.testTranscribe(en, language: .english, forcePreview: true)
        try await waitForPreview(engine)
        precondition(engine.previewText.localizedCaseInsensitiveContains("English"))
        engine.retryPreviewLanguage(.english)
        try await Task.sleep(nanoseconds: 200_000_000)
        engine.cancelCurrentOperation()
        try await Task.sleep(nanoseconds: 8_000_000_000)
        precondition(engine.state == .idle && !engine.canRetryPreviewLanguage && engine.previewText.isEmpty)
        engine.acceptPreview() // A stale acceptance must not dispatch anything.
        precondition(engine.state == .idle)
        precondition(DictationMemory.shared.history.isEmpty)
        precondition(NSPasteboard.general.changeCount == boardCount, "Review must never touch the clipboard")
        print("Language review engine passed: uncertain Auto, manual EN/BG, retry serialization, expiry, discard, cancellation, stale accept, no history/clipboard delivery.")
    }

    @MainActor private static func waitForPreview(_ engine: DictationEngine) async throws {
        for _ in 0..<1200 {
            if engine.state == .preview { return }
            precondition(engine.state == .processing, "Unexpected delivery or idle transition")
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        fatalError("Recognition timed out")
    }

    private static func audio(_ name: String) throws -> [Float] {
        let file = try AVAudioFile(forReading: URL(fileURLWithPath: CommandLine.arguments[2]).appendingPathComponent(name))
        let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
        try file.read(into: buffer)
        return Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
    }
}
