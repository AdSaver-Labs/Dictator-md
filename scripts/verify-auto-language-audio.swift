import AVFoundation
import Foundation

@main
struct AutoLanguageAudioSmoke {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            fputs("Usage: verify-auto-language-audio <multilingual-model-path>\n", stderr)
            exit(2)
        }

        let bridge = try WhisperBridge(modelPath: CommandLine.arguments[1])
        let phrases: [(voice: String, text: String, language: AppSettings.DictationLanguage)] = [
            ("Samantha", "Hello, today I want to test this dictation in English.", .english),
            ("Daria", "Здравейте, днес искам да изпробвам тази диктовка на български.", .bulgarian),
            ("Samantha", "Hello.", .english),
            ("Daria", "Здравейте.", .bulgarian)
        ]

        for phrase in phrases {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("dictatormd-language-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }

            let source = directory.appendingPathComponent("speech.aiff")
            let converted = directory.appendingPathComponent("speech.caf")
            try run("/usr/bin/say", ["-v", phrase.voice, "-o", source.path, phrase.text])
            try run("/usr/bin/afconvert", [source.path, "-o", converted.path, "-f", "caff", "-d", "LEF32@16000", "-c", "1"])

            let file = try AVAudioFile(forReading: converted)
            let frameCount = AVAudioFrameCount(file.length)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount) else {
                fatalError("Could not allocate audio buffer")
            }
            try file.read(into: buffer)
            guard let samples = buffer.floatChannelData?[0] else {
                fatalError("Converted audio is not Float32")
            }

            let result = bridge.transcribe(
                audioBuffer: Array(UnsafeBufferPointer(start: samples, count: Int(buffer.frameLength))),
                language: .auto,
                useVAD: false
            )
            print("\(phrase.voice): selected=\(result.language.whisperCode) transcript=\(result.text)")
            guard result.language == phrase.language else {
                fputs("Auto detection selected the wrong language for \(phrase.voice).\n", stderr)
                exit(1)
            }
        }
    }

    private static func run(_ executable: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            fatalError("\(executable) exited with \(process.terminationStatus)")
        }
    }
}
