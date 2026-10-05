import Foundation

/// Recognition hints only: glossary entries never perform fuzzy text replacement.
enum RecognitionVocabulary {
    struct Context {
        var customTerms: [String] = []
        var confirmedTerms: [String] = []
        var confirmedCorrections: [PersonalCorrection] = []
        var learnedTerms: [String] = []
        var basePrompt: String = ""
    }
    struct Entry {
        let spelling: String
        let language: AppSettings.DictationLanguage
        let cues: [String]
    }

    static let glossary: [Entry] = [
        Entry(spelling: "диклофенак", language: .bulgarian, cues: ["дикло", "фенак", "лекар", "аптек"]),
        Entry(spelling: "Допелхерц", language: .bulgarian, cues: ["допел", "допъл", "херц", "витамин", "добавк"]),
        Entry(spelling: "парацетамол", language: .bulgarian, cues: ["парац", "цетам", "лекар", "аптек"]),
        Entry(spelling: "ибупрофен", language: .bulgarian, cues: ["ибуп", "профен", "лекар", "аптек"]),
        Entry(spelling: "diclofenac", language: .english, cues: ["diclo", "fenac", "medication", "pharmacy"]),
        Entry(spelling: "Doppelherz", language: .english, cues: ["doppel", "herz", "vitamin", "supplement"]),
        Entry(spelling: "paracetamol", language: .english, cues: ["paracet", "medication", "pharmacy"]),
        Entry(spelling: "ibuprofen", language: .english, cues: ["ibup", "medication", "pharmacy"]),
        Entry(spelling: "Благоевград", language: .bulgarian, cues: ["благо", "град"]),
        Entry(spelling: "Кюстендил", language: .bulgarian, cues: ["кюст", "град"]),
        Entry(spelling: "Велико Търново", language: .bulgarian, cues: ["търнов", "град"]),
        Entry(spelling: "щото, кво, някъв, днеска", language: .bulgarian, cues: []),
        Entry(spelling: "промпт, шорткът, бекенд, фронтенд", language: .bulgarian, cues: ["код", "апликац", "репо"]),
        Entry(spelling: "Openclaw, Hermes, Codex", language: .auto, cues: ["agent", "агент", "project", "проект"]),
        Entry(spelling: "Notion, Telegram, ChatGPT", language: .auto, cues: []),
        Entry(spelling: "API, GitHub, PostgreSQL, Kubernetes", language: .auto, cues: ["code", "код", "database", "база"])
    ]

    static func allows(_ text: String, language: AppSettings.DictationLanguage) -> Bool {
        guard !text.unicodeScalars.contains(where: { "ыэёЫЭЁ".unicodeScalars.contains($0) }) else { return false }
        return language != .english || !containsCyrillic(text)
    }

    static func containsCyrillic(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x0400...0x052F).contains($0.value) }
    }

    static func learnedHints(_ terms: [LearnedTerm], language: AppSettings.DictationLanguage, limit: Int) -> [String] {
        Array(terms.filter { $0.count >= 2 && allows($0.term, language: language) }.prefix(limit).map(\.term))
    }

    /// The tokenizer belongs to the loaded ASR engine; word counts are not token budgets.
    static func prompt(
        language: AppSettings.DictationLanguage,
        customTerms: [String],
        confirmedTerms: [String],
        learnedTerms: [String],
        basePrompt: String,
        recognizedContext: String = "",
        tokenBudget: Int = 216,
        tokenCount: (String) -> Int
    ) -> String {
        let context = recognizedContext.lowercased()
        let eligible = glossary.filter { $0.language == .auto || $0.language == language || language == .auto }
        let relevant = eligible.filter { entry in
            !context.isEmpty && entry.cues.contains { context.contains($0) }
        }.map(\.spelling)
        let defaults = eligible.map(\.spelling)
        // Explicit vocabulary takes priority over unverified transcript-derived terms.
        let candidates = relevant + customTerms + confirmedTerms + defaults + baseEntries(basePrompt) + learnedTerms
        var seen = Set<String>()
        var selected: [String] = []
        for candidate in candidates {
            let term = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !term.isEmpty, term.count <= 160, allows(term, language: language),
                  seen.insert(term.lowercased()).inserted else { continue }
            let proposal = (selected + [term]).joined(separator: ", ")
            let count = tokenCount(proposal)
            guard count >= 0, count <= tokenBudget else { continue }
            selected.append(term)
        }
        return selected.joined(separator: ", ")
    }

    private static func baseEntries(_ prompt: String) -> [String] {
        prompt.components(separatedBy: .newlines).flatMap { line -> [String] in
            let lower = line.lowercased()
            // Migrate the old instruction-heavy default without changing saved settings.
            guard !["dictation should", "if the user", "bulgarian dictation may", "transcribe ", "never output"]
                .contains(where: lower.contains) else { return [] }
            let content = line.contains(":") ? String(line.split(separator: ":", maxSplits: 1).last ?? "") : line
            return content.components(separatedBy: ",")
        }
    }
}
