import AVFoundation
import Foundation

/// Synthetic speech is a wiring/accuracy smoke test, not a substitute for a user's recordings.
@main
struct RecognitionAudioSmoke {
    struct SpeechPart: Codable, Equatable {
        let voice: String
        let text: String
    }
    struct Fixture: Codable, Equatable {
        let voice: String
        let text: String
        let expectedLanguage: String
        let terms: [String]
        var leadingSilenceSeconds: Double = 0
        var gain: Float = 1
        var requestedLanguage: String = "auto"
        var parts: [SpeechPart] = []
        var expectedReview: Bool?
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
        let languageMatched: Bool
        let requiresLanguageReview: Bool
        let reviewMatched: Bool
    }

    static func main() throws {
        guard CommandLine.arguments.count == 4 else {
            fputs("Usage: verify-recognition-audio <existing-model> <fixture-directory> <results.json>\n", stderr)
            exit(2)
        }
        let directory = URL(fileURLWithPath: CommandLine.arguments[2])
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var fixtures = [
            Fixture(voice: "Daria", text: "Искам да запиша думите диклофенак и Допелхерц правилно на български.", expectedLanguage: "bg", terms: ["диклофенак", "Допелхерц"]),
            Fixture(voice: "Samantha", text: "Please spell diclofenac and Doppelherz correctly in this English note.", expectedLanguage: "en", terms: ["diclofenac", "Doppelherz"]),
            Fixture(voice: "Daria", text: "Днес пътувах от Благоевград до Кюстендил и после до Велико Търново.", expectedLanguage: "bg", terms: ["Благоевград", "Кюстендил", "Велико Търново"]),
            Fixture(voice: "Samantha", text: "The project uses PostgreSQL and Kubernetes. Please ask Hermes to review the GitHub changes.", expectedLanguage: "en", terms: ["PostgreSQL", "Kubernetes", "Hermes", "GitHub"]),
            Fixture(voice: "Daria", text: "Здравейте, искам да запиша една по-дълга бележка на български. Днес проверих историята на приложението и настройките за разпознаване на реч. Думите диклофенак и Допелхерц трябва да останат на български. След това ще запиша имената Благоевград и Кюстендил. Не искам приложението да превежда тази бележка на английски. Искам да запази думите, които произнасям, без повторение на изреченията и без да променя числото 15.", expectedLanguage: "bg", terms: ["диклофенак", "Допелхерц", "Благоевград", "Кюстендил", "15"]),
            Fixture(voice: "Samantha", text: "This is a longer English note about our application. We need to preserve uncommon product names, technical vocabulary, and the original meaning of the recording. The project uses PostgreSQL and Kubernetes. I want Hermes to review the GitHub changes, and I want the medicine names diclofenac and Doppelherz to be spelled correctly. Please keep the number 15 unchanged. This test does not prove that every word will be recognized, but it gives us the same recording to compare before and after the recognition update.", expectedLanguage: "en", terms: ["PostgreSQL", "Kubernetes", "Hermes", "GitHub", "diclofenac", "Doppelherz", "15"])
        ]
        fixtures += [
            Fixture(voice: "Daria", text: "Днес ще проверим настройките на приложението и ще запишем една бележка на български.", expectedLanguage: "bg", terms: [], leadingSilenceSeconds: 12),
            Fixture(voice: "Samantha", text: "Today we will check the application settings and write a short note in English.", expectedLanguage: "en", terms: [], leadingSilenceSeconds: 12),
            Fixture(voice: "Daria", text: "Искам тази бележка да остане на български. Утре ще пътувам до Благоевград.", expectedLanguage: "bg", terms: ["Благоевград"], gain: 0.015),
            Fixture(voice: "Samantha", text: "Please keep this note in English. Tomorrow I will review the project settings.", expectedLanguage: "en", terms: [], gain: 0.015),
            Fixture(voice: "Daria", text: "Окей, искам да проверим историята на приложението и да запазим всички думи на български.", expectedLanguage: "bg", terms: []),
            Fixture(voice: "Samantha", text: "Okay, I want to check the application history and keep all these words in English.", expectedLanguage: "en", terms: []),
            Fixture(voice: "Daria", text: "Запиши тази бележка на български и запази числото 15.", expectedLanguage: "bg", terms: ["15"], requestedLanguage: "bg"),
            Fixture(voice: "Samantha", text: "Write this note in English and preserve the number 15.", expectedLanguage: "en", terms: ["15"], requestedLanguage: "en"),
            Fixture(voice: "Daria", text: "Искам да запишем тази бележка на български. Днес пътувах до Благоевград.", expectedLanguage: "bg", terms: ["Благоевград"], leadingSilenceSeconds: 32),
            Fixture(voice: "Samantha", text: "I want to record this note in English. Today I reviewed the application settings.", expectedLanguage: "en", terms: [], leadingSilenceSeconds: 32)
        ]
        fixtures += [
            Fixture(voice: "Daria", text: "Помоли Хермес да провери деплоймента в Кубернетес и да качи промените в Гитхъб.", expectedLanguage: "bg", terms: ["Hermes", "Kubernetes", "GitHub"]),
            Fixture(voice: "Samantha", text: "Please keep the Bulgarian names Благоевград and Кюстендил unchanged in this note.", expectedLanguage: "en", terms: [], parts: [
                SpeechPart(voice: "Samantha", text: "Please keep the Bulgarian names"),
                SpeechPart(voice: "Daria", text: "Благоевград"),
                SpeechPart(voice: "Samantha", text: "and"),
                SpeechPart(voice: "Daria", text: "Кюстендил"),
                SpeechPart(voice: "Samantha", text: "unchanged in this note.")]),
            Fixture(voice: "Daria", text: "Моля провери настройките на проекта в GitHub and Kubernetes преди срещата утре.", expectedLanguage: "bg", terms: ["GitHub", "Kubernetes"], parts: [
                SpeechPart(voice: "Daria", text: "Моля провери настройките на проекта в"),
                SpeechPart(voice: "Samantha", text: "GitHub and Kubernetes"),
                SpeechPart(voice: "Daria", text: "преди срещата утре.")])
        ]
        if ProcessInfo.processInfo.environment["DICTATOR_TEST_CONFLICT"] == "1" {
            fixtures = [Fixture(voice: "Samantha", text: "Please write down the following names for this project. Днес проверих настройките на приложението и историята на всички съобщения. Утре ще пътувам до Благоевград и Кюстендил.", expectedLanguage: "en", terms: [], parts: [
                SpeechPart(voice: "Samantha", text: "Please write down the following names for this project."),
                SpeechPart(voice: "Daria", text: "Днес проверих настройките на приложението и историята на всички съобщения. Утре ще пътувам до Благоевград и Кюстендил.")], expectedReview: true)]
        }
        let referencesURL = directory.appendingPathComponent("references.json")
        if let previous = try? Data(contentsOf: referencesURL) {
            guard try JSONDecoder().decode([Fixture].self, from: previous) == fixtures else {
                fatalError("Fixture definitions changed; use a fresh scratch directory rather than stale cached audio")
            }
        }
        try JSONEncoder().encode(fixtures).write(to: referencesURL, options: .atomic)
        let bridge = try WhisperBridge(modelPath: CommandLine.arguments[1])
        let useVAD = ProcessInfo.processInfo.environment["DICTATOR_TEST_VAD"] == "1"
        var results: [Result] = []
        for (index, fixture) in fixtures.enumerated() {
            let parts = fixture.parts.isEmpty ? [SpeechPart(voice: fixture.voice, text: fixture.text)] : fixture.parts
            var speech: [Float] = []
            for (partIndex, part) in parts.enumerated() {
                let stem = fixture.parts.isEmpty ? "\(index)" : "\(index)-\(partIndex)"
                let source = directory.appendingPathComponent("\(stem).aiff")
                let converted = directory.appendingPathComponent("\(stem).caf")
                if !FileManager.default.fileExists(atPath: converted.path) {
                    try run("/usr/bin/say", ["-v", part.voice, "-o", source.path, part.text])
                    try run("/usr/bin/afconvert", [source.path, "-o", converted.path, "-f", "caff", "-d", "LEF32@16000", "-c", "1"])
                }
                let file = try AVAudioFile(forReading: converted)
                guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else { fatalError("Audio allocation") }
                try file.read(into: buffer)
                guard let samples = buffer.floatChannelData?[0] else { fatalError("Expected Float32 audio") }
                speech += Array(UnsafeBufferPointer(start: samples, count: Int(buffer.frameLength)))
            }
            let audio = [Float](repeating: 0, count: Int(fixture.leadingSilenceSeconds * 16000))
                + speech.map { $0 * fixture.gain }
            let requestedLanguage = AppSettings.DictationLanguage(rawValue: fixture.requestedLanguage)!
            let start = Date()
            #if BASELINE
            let transcription = bridge.transcribe(audioBuffer: audio, language: requestedLanguage, useVAD: useVAD,
                vocabulary: RecognitionVocabulary.Context(customTerms: ["Openclaw", "Hermes"], basePrompt: AppSettings.defaultVocabularyPrompt))
            let needsReview = false
            #else
            let transcription = bridge.transcribe(audioBuffer: audio, language: requestedLanguage, useVAD: useVAD,
                vocabulary: RecognitionVocabulary.Context(customTerms: ["Openclaw", "Hermes"], basePrompt: AppSettings.defaultVocabularyPrompt))
            let needsReview = transcription.requiresLanguageReview
            #endif
            let languageMatched = transcription.language.rawValue == fixture.expectedLanguage
            let found = fixture.terms.filter { transcription.text.localizedCaseInsensitiveContains($0) }.count
            let result = Result(fixture: index, reference: fixture.text, transcript: transcription.text,
                language: transcription.language.rawValue, seconds: Date().timeIntervalSince(start),
                wordErrorRate: wordErrorRate(reference: fixture.text, actual: transcription.text),
                recognizedTerms: found, expectedTerms: fixture.terms.count, languageMatched: languageMatched,
                requiresLanguageReview: needsReview, reviewMatched: needsReview == (fixture.expectedReview ?? false))
            results.append(result)
            print("Fixture \(index): \(result.language) languageMatched=\(languageMatched) reviewMatched=\(result.reviewMatched) WER=\(String(format: "%.3f", result.wordErrorRate)) terms=\(found)/\(fixture.terms.count) seconds=\(String(format: "%.2f", result.seconds))")
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(results).write(to: URL(fileURLWithPath: CommandLine.arguments[3]), options: .atomic)
        guard results.allSatisfy({ $0.languageMatched && $0.reviewMatched }) else { exit(1) }
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
