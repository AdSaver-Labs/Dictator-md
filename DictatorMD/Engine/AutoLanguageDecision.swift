import Foundation

enum AutoLanguageDecision {
    /// A confident opening in the other language is a conflict, not permission
    /// to force the entire recording into the language of its later names.
    static func reconcile(opening: AppSettings.DictationLanguage?, broader: AppSettings.DictationLanguage?) -> AppSettings.DictationLanguage? {
        guard let broader, broader != .auto else { return nil }
        guard opening == nil || opening == broader else { return nil }
        return broader
    }

    static func choose(
        english: Float,
        bulgarian: Float,
        topLanguage: String,
        requireStrongEvidence: Bool
    ) -> AppSettings.DictationLanguage? {
        guard english.isFinite, bulgarian.isFinite,
              (0...1).contains(english), (0...1).contains(bulgarian),
              english + bulgarian <= 1.0001 else { return nil }
        // An unsupported language is not evidence for Bulgarian. In particular,
        // never turn a weak Polish/Russian classification into a Bulgarian lock.
        guard topLanguage == "en" || topLanguage == "bg" else { return nil }
        let supportedTotal = english + bulgarian
        let minimumTotal: Float = requireStrongEvidence ? 0.55 : 0.35
        guard supportedTotal >= minimumTotal else { return nil }

        let share = max(english, bulgarian) / supportedTotal
        let minimumShare: Float = requireStrongEvidence ? 0.80 : 0.70
        guard share >= minimumShare else { return nil }
        let winner: AppSettings.DictationLanguage = bulgarian > english ? .bulgarian : .english
        return winner.whisperCode == topLanguage ? winner : nil
    }
}

/// A detection-only copy. The recognizer still receives every original sample.
struct AutoLanguageSample {
    let samples: [Float]
    let offset: Int
    let gain: Float

    static func prepare(_ audio: [Float]) -> AutoLanguageSample? {
        let frameSize = 320 // 20 ms at the capture contract's 16 kHz.
        let scanCount = min(audio.count, 60 * 16000)
        guard scanCount > 0 else { return nil }
        var energies: [Double] = []
        for start in stride(from: 0, to: scanCount, by: frameSize) {
            let frame = audio[start..<min(start + frameSize, scanCount)]
            guard frame.allSatisfy(\.isFinite) else { return nil }
            energies.append(sqrt(frame.reduce(0) { $0 + Double($1) * Double($1) } / Double(frame.count)))
        }
        guard let maximum = energies.max(), maximum > 0.0000001 else { return nil }
        // Conservative relative floor: retain quiet openings before louder speech.
        // Three sustained frames reject an isolated click; keep 300 ms pre-roll.
        let threshold = max(0.0000001, min(0.00001, maximum * 0.01))
        var run = 0
        var onset: Int?
        for (index, energy) in energies.enumerated() {
            run = energy >= threshold ? run + 1 : 0
            if run == 3 { onset = max(0, (index - 2) * frameSize - 4800); break }
        }
        guard let onset else { return nil }
        let end = min(audio.count, onset + 30 * 16000)
        let window = audio[onset..<end]
        guard window.allSatisfy(\.isFinite) else { return nil }
        let peak = window.reduce(Float(0)) { max($0, abs($1)) }
        let gain = max(1, min(8, 0.15 / max(peak, 0.0000001)))
        return AutoLanguageSample(samples: window.map { $0 * gain }, offset: onset, gain: gain)
    }
}

/// Short-lived recovery, never written to disk. Expiry also has an engine timer.
struct LanguageReviewAudio {
    static let lifetime: TimeInterval = 300
    static let maximumSamples = 10 * 60 * 16000
    private let audio: [Float]
    let expiresAt: Date

    init?(_ audio: [Float], now: Date = Date()) {
        guard !audio.isEmpty, audio.count <= Self.maximumSamples else { return nil }
        self.audio = audio
        expiresAt = now.addingTimeInterval(Self.lifetime)
    }

    func samples(at now: Date = Date()) -> [Float]? {
        now < expiresAt ? audio : nil
    }
}
