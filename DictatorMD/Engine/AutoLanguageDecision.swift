import Foundation

enum AutoLanguageDecision {
    static func choose(
        english: Float,
        bulgarian: Float,
        topLanguage: String,
        requireStrongEvidence: Bool
    ) -> AppSettings.DictationLanguage? {
        guard english.isFinite, bulgarian.isFinite, english >= 0, bulgarian >= 0 else { return nil }
        // Short Bulgarian words can resemble a neighboring Slavic language to
        // Whisper's broad classifier even when the Bulgarian score is tiny.
        let neighboringSlavic: Set<String> = ["pl", "ru", "uk", "be", "cs", "sk", "sl", "hr", "sr", "bs", "mk"]
        if !requireStrongEvidence, english < 0.30, neighboringSlavic.contains(topLanguage) {
            return .bulgarian
        }
        let supportedTotal = english + bulgarian
        let minimumTotal: Float = requireStrongEvidence ? 0.35 : 0.15
        guard supportedTotal >= minimumTotal else { return nil }

        let share = max(english, bulgarian) / supportedTotal
        let minimumShare: Float = requireStrongEvidence ? 0.80 : 0.58
        guard share >= minimumShare else { return nil }
        return bulgarian > english ? .bulgarian : .english
    }
}
