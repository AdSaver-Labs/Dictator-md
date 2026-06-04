import AppKit
import Foundation

struct DictationHistoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let text: String
    let language: String
    let appName: String
    let bundleIdentifier: String
    let audioDuration: Double
    let wordCount: Int
}

struct LearnedTerm: Identifiable, Codable, Equatable {
    var id: String { term.lowercased() }
    let term: String
    var count: Int
    var firstSeen: Date?
    var lastSeen: Date
}

final class DictationMemory: ObservableObject, @unchecked Sendable {
    static nonisolated(unsafe) let shared = DictationMemory()

    @Published private(set) var history: [DictationHistoryItem] = []
    @Published private(set) var learnedTerms: [LearnedTerm] = []

    private let fileURL: URL
    private let maxHistoryItems = 500
    private let maxLearnedTerms = 300

    private struct Store: Codable {
        var history: [DictationHistoryItem]
        var learnedTerms: [LearnedTerm]
    }

    private init() {
        fileURL = AppPaths.supportDirectory().appendingPathComponent("memory.json")
        load()
    }

    func record(text: String, language: AppSettings.DictationLanguage, targetApp: NSRunningApplication?, audioDuration: Double) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let item = DictationHistoryItem(
            id: UUID(),
            timestamp: Date(),
            text: trimmed,
            language: language.label,
            appName: targetApp?.localizedName ?? "Unknown",
            bundleIdentifier: targetApp?.bundleIdentifier ?? "",
            audioDuration: audioDuration,
            wordCount: Self.wordCount(in: trimmed)
        )

        let candidates = Self.extractCandidateTerms(from: trimmed)
        DispatchQueue.main.async {
            var newHistory = self.history
            var newTerms = self.learnedTerms
            newHistory.insert(item, at: 0)
            if newHistory.count > self.maxHistoryItems {
                newHistory.removeLast(newHistory.count - self.maxHistoryItems)
            }

            for candidate in candidates {
                if let index = newTerms.firstIndex(where: { $0.term.caseInsensitiveCompare(candidate) == .orderedSame }) {
                    newTerms[index].count += 1
                    newTerms[index].lastSeen = Date()
                    if newTerms[index].firstSeen == nil {
                        newTerms[index].firstSeen = newTerms[index].lastSeen
                    }
                } else {
                    let now = Date()
                    newTerms.append(LearnedTerm(term: candidate, count: 1, firstSeen: now, lastSeen: now))
                }
            }

            newTerms.sort {
                if $0.count == $1.count { return $0.lastSeen > $1.lastSeen }
                return $0.count > $1.count
            }
            if newTerms.count > self.maxLearnedTerms {
                newTerms.removeLast(newTerms.count - self.maxLearnedTerms)
            }

            self.history = newHistory
            self.learnedTerms = newTerms
            self.save(Store(history: newHistory, learnedTerms: newTerms))
            DebugLog.shared.log("[DictationMemory] recorded words=\(item.wordCount) candidates=\(candidates.count) learned=\(newTerms.count)")
        }
    }

    func topPromptTerms(for language: AppSettings.DictationLanguage, limit: Int = 80) -> [String] {
        Array(learnedTerms
            .filter { term in
                guard !Self.containsRussianOnlyCyrillic(term.term) else { return false }

                switch language {
                case .english, .auto:
                    return !Self.containsCyrillic(term.term) && term.count >= 2
                case .bulgarian:
                    return term.count >= 2 || Self.containsCyrillic(term.term)
                }
            }
            .prefix(limit)
            .map(\.term))
    }

    func promoteToCustomTerm(_ term: String) {
        AppSettings.shared.addCustomTerm(term)
    }

    func removeLearnedTerm(_ term: String) {
        let newTerms = learnedTerms.filter { $0.term != term }
        learnedTerms = newTerms
        let store = Store(history: history, learnedTerms: newTerms)
        save(store)
    }

    func clearHistory() {
        history = []
        let store = Store(history: [], learnedTerms: learnedTerms)
        save(store)
    }

    func clearLearnedTerms() {
        learnedTerms = []
        let store = Store(history: history, learnedTerms: [])
        save(store)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let store = try? JSONDecoder().decode(Store.self, from: data) else {
            return
        }
        history = store.history
        learnedTerms = store.learnedTerms
    }

    private func save(_ store: Store) {
        DispatchQueue.global(qos: .utility).async { [fileURL] in
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(store) {
                try? data.write(to: fileURL, options: .atomic)
            }
        }
    }

    private static func wordCount(in text: String) -> Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    private static func extractCandidateTerms(from text: String) -> [String] {
        let allowed = CharacterSet.letters
            .union(.decimalDigits)
            .union(CharacterSet(charactersIn: "#+-_."))
        let rawTokens = text.components(separatedBy: allowed.inverted)
        var seen = Set<String>()
        var terms: [String] = []

        for rawToken in rawTokens {
            let token = rawToken.trimmingCharacters(in: CharacterSet(charactersIn: "#+-_."))
            guard token.count >= 3, token.count <= 36 else { continue }
            guard !Self.stopWords.contains(token.lowercased()) else { continue }

            let shouldLearn = containsCyrillic(token)
                || containsDigit(token)
                || hasTechShape(token)
                || hasDistinctiveCapitalization(token)
            guard shouldLearn else { continue }

            let key = token.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            terms.append(token)
        }

        return terms
    }

    private static func containsCyrillic(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x0400...0x04FF).contains(Int(scalar.value))
        }
    }

    private static func containsRussianOnlyCyrillic(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            ["ы", "э", "ё"].contains(String(scalar).lowercased())
        }
    }

    private static func containsDigit(_ text: String) -> Bool {
        text.unicodeScalars.contains { CharacterSet.decimalDigits.contains($0) }
    }

    private static func hasTechShape(_ text: String) -> Bool {
        text.contains("#") || text.contains("+") || text.contains(".") || text.contains("_") || text.contains("-")
    }

    private static func hasDistinctiveCapitalization(_ text: String) -> Bool {
        let scalars = text.unicodeScalars
        let uppercaseCount = scalars.filter { CharacterSet.uppercaseLetters.contains($0) }.count
        guard uppercaseCount > 0 else { return false }

        let lowercaseCount = scalars.filter { CharacterSet.lowercaseLetters.contains($0) }.count
        if uppercaseCount >= 2 {
            return true
        }

        guard let first = scalars.first,
              CharacterSet.uppercaseLetters.contains(first),
              lowercaseCount >= 2 else {
            return false
        }

        // Learn probable names/products, but avoid ordinary sentence-start words.
        return text.count >= 6
    }

    private static let stopWords: Set<String> = [
        "the", "and", "for", "that", "this", "with", "you", "your", "have", "has",
        "are", "was", "were", "but", "not", "can", "could", "would", "should",
        "just", "now", "right", "really", "very", "when", "what", "where", "why",
        "how", "into", "from", "about", "there", "their", "then", "than", "also",
        "или", "ако", "как", "като", "това", "този", "тази", "тези", "съм", "си",
        "сме", "сте", "има", "няма", "много", "само", "нещо", "защо", "кога"
    ]
}
