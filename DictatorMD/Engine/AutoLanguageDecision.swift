import Foundation

enum AutoLanguageDecision {
    static func choose(
        english: Float,
        bulgarian: Float,
        topLanguage: String,
        requireStrongEvidence: Bool
    ) -> AppSettings.DictationLanguage? {
        guard english.isFinite, bulgarian.isFinite, english >= 0, bulgarian >= 0 else { return nil }
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
