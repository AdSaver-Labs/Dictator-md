import AVFoundation
import Foundation

/// Synthetic speech is a wiring/accuracy smoke test, not a substitute for a user's recordings.
@main
struct RecognitionAudioSmoke {
    struct Fixture: Codable {
        let voice: String
        let text: String
        let expectedLanguage: String
        let terms: [String]
    }
    struct Result: Codable {
        let fixture: Int
        let reference: String
        let transcript: String
        let language: String
        let seconds: Double
        let wordErrorRate: Double
        let recognizedTerms: Int
        let expectedTerms: Int
    }

    static func main() throws {
        guard CommandLine.arguments.count == 4 else {
            fputs("Usage: verify-recognition-audio <existing-model> <fixture-directory> <results.json>\n", stderr)
            exit(2)
        }
        let directory = URL(fileURLWithPath: CommandLine.arguments[2])
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fixtures = [
            Fixture(voice: "Daria", text: "Искам да запиша думите диклофенак и Допелхерц правилно на български.", expectedLanguage: "bg", terms: ["диклофенак", "Допелхерц"]),
            Fixture(voice: "Samantha", text: "Please spell diclofenac and Doppelherz correctly in this English note.", expectedLanguage: "en", terms: ["diclofenac", "Doppelherz"]),
            Fixture(voice: "Daria", text: "Днес пътувах от Благоевград до Кюстендил и после до Велико Търново.", expectedLanguage: "bg", terms: ["Благоевград", "Кюстендил", "Велико Търново"]),
            Fixture(voice: "Samantha", text: "The project uses PostgreSQL and Kubernetes. Please ask Hermes to review the GitHub changes.", expectedLanguage: "en", terms: ["PostgreSQL", "Kubernetes", "Hermes", "GitHub"]),
            Fixture(voice: "Daria", text: "Здравейте, искам да запиша една по-дълга бележка на български. Днес проверих историята на приложението и настройките за разпознаване на реч. Думите диклофенак и Допелхерц трябва да останат на български. След това ще запиша имената Благоевград и Кюстендил. Не искам приложението да превежда тази бележка на английски. Искам да запази думите, които произнасям, без повторение на изреченията и без да променя числото 15.", expectedLanguage: "bg", terms: ["диклофенак", "Допелхерц", "Благоевград", "Кюстендил", "15"]),
            Fixture(voice: "Samantha", text: "This is a longer English note about our application. We need to preserve uncommon product names, technical vocabulary, and the original meaning of the recording. The project uses PostgreSQL and Kubernetes. I want Hermes to review the GitHub changes, and I want the medicine names diclofenac and Doppelherz to be spelled correctly. Please keep the number 15 unchanged. This test does not prove that every word will be recognized, but it gives us the same recording to compare before and after the recognition update.", expectedLanguage: "en", terms: ["PostgreSQL", "Kubernetes", "Hermes", "GitHub", "diclofenac", "Doppelherz", "15"])
        ]
        try JSONEncoder().encode(fixtures).write(to: directory.appendingPathComponent("references.json"), options: .atomic)
        let bridge = try WhisperBridge(modelPath: CommandLine.arguments[1])
        var results: [Result] = []
        for (index, fixture) in fixtures.enumerated() {
            let source = directory.appendingPathComponent("\(index).aiff")
            let converted = directory.appendingPathComponent("\(index).caf")
            if !FileManager.default.fileExists(atPath: converted.path) {
                try run("/usr/bin/say", ["-v", fixture.voice, "-o", source.path, fixture.text])
                try run("/usr/bin/afconvert", [source.path, "-o", converted.path, "-f", "caff", "-d", "LEF32@16000", "-c", "1"])
            }
            let file = try AVAudioFile(forReading: converted)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else { fatalError("Audio allocation") }
            try file.read(into: buffer)
            guard let samples = buffer.floatChannelData?[0] else { fatalError("Expected Float32 audio") }
            let audio = Array(UnsafeBufferPointer(start: samples, count: Int(buffer.frameLength)))
            let start = Date()
            #if BASELINE
            let transcription = bridge.transcribe(audioBuffer: audio, language: .auto, useVAD: false,
                prompt: AppSettings.defaultVocabularyPrompt + ", Learned user terms: Openclaw, Hermes")
            #else
            let transcription = bridge.transcribe(audioBuffer: audio, language: .auto, useVAD: false,
                vocabulary: RecognitionVocabulary.Context(customTerms: ["Openclaw", "Hermes"], basePrompt: AppSettings.defaultVocabularyPrompt))
            #endif
            guard transcription.language.rawValue == fixture.expectedLanguage else { fatalError("Wrong language for fixture \(index)") }
            let found = fixture.terms.filter { transcription.text.localizedCaseInsensitiveContains($0) }.count
            let result = Result(fixture: index, reference: fixture.text, transcript: transcription.text,
                language: transcription.language.rawValue, seconds: Date().timeIntervalSince(start),
                wordErrorRate: wordErrorRate(reference: fixture.text, actual: transcription.text),
                recognizedTerms: found, expectedTerms: fixture.terms.count)
            results.append(result)
            print("Fixture \(index): \(result.language) WER=\(String(format: "%.3f", result.wordErrorRate)) terms=\(found)/\(fixture.terms.count) seconds=\(String(format: "%.2f", result.seconds))")
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(results).write(to: URL(fileURLWithPath: CommandLine.arguments[3]), options: .atomic)
    }

    private static func wordErrorRate(reference: String, actual: String) -> Double {
        func words(_ text: String) -> [String] {
            text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        }
        let expected = words(reference), recognized = words(actual)
        var previous = Array(0...recognized.count)
        for (index, word) in expected.enumerated() {
            var next = [index + 1]
            for (otherIndex, otherWord) in recognized.enumerated() {
                next.append(min(next[otherIndex] + 1, previous[otherIndex + 1] + 1,
                                previous[otherIndex] + (word == otherWord ? 0 : 1)))
            }
            previous = next
        }
        return Double(previous.last ?? 0) / Double(max(1, expected.count))
    }

    private static func run(_ path: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { fatalError("\(path) failed") }
    }
}
