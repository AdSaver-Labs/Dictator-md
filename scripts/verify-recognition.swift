import Foundation

@main
struct RecognitionSmoke {
    static func main() throws {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            guard condition() else { fatalError(message) }
            checks += 1
        }
        let now = Date()
        let terms = [LearnedTerm(term: "Благоевград", count: 3, lastSeen: now),
                     LearnedTerm(term: "Doppelherz", count: 2, lastSeen: now),
                     LearnedTerm(term: "ыtest", count: 4, lastSeen: now),
                     LearnedTerm(term: "unconfirmed", count: 1, lastSeen: now)]
        check(RecognitionVocabulary.learnedHints(terms, language: .auto, limit: 80).contains("Благоевград"), "Auto discarded Bulgarian")
        check(!RecognitionVocabulary.learnedHints(terms, language: .english, limit: 80).contains("Благоевград"), "English polluted")
        check(RecognitionVocabulary.learnedHints(terms, language: .auto, limit: 80).count == 2, "Unconfirmed/Russian hints")
        let tokenCount: (String) -> Int = { $0.utf8.count } // Intentionally expensive tokenizer to test packing.
        let prompt = RecognitionVocabulary.prompt(language: .auto, customTerms: ["MyTerm", "myterm", String(repeating: "x", count: 300)],
            confirmedTerms: ["диклофенак"], learnedTerms: ["old"], basePrompt: "", tokenBudget: 90, tokenCount: tokenCount)
        check(tokenCount(prompt) <= 90, "Exceeded token budget")
        check(prompt.contains("MyTerm") && prompt.contains("диклофенак"), "Lost priority hints")
        check(!prompt.contains("myterm"), "Duplicate hints")
        let english = RecognitionVocabulary.prompt(language: .english, customTerms: ["Благоевград", "Doppelherz"],
            confirmedTerms: [], learnedTerms: [], basePrompt: "Transcribe only in English\nLanguages: Swift, Python", tokenCount: { $0.count })
        check(!RecognitionVocabulary.containsCyrillic(english), "Mixed scripts in English hints")
        check(!english.contains("Transcribe"), "Instruction in hints")
        check(english.contains("Doppelherz"), "Lost brand")

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dictatormd-corrections-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let memory = PersonalCorrections(fileURL: url)
        check(memory.confirm(heard: "дикло фенак", spelling: "диклофенак", language: .bulgarian, context: ""), "Could not save")
        check(PersonalCorrections(fileURL: url).items == memory.items, "Persistence failed")
        check(PersonalCorrection.apply(memory.items, to: "Това е дикло   фенак, не друго.", language: .bulgarian) == "Това е диклофенак, не друго.", "Phrase correction failed")
        check(PersonalCorrection.apply(memory.items, to: "дикло фенак", language: .english) == "дикло фенак", "Language scope failed")
        let bilingual = PersonalCorrection.validated(heard: "diclo fenac", spelling: "диклофенак", language: .auto, context: "")!
        check(PersonalCorrection.apply([bilingual], to: "diclo fenac", language: .english) == "diclo fenac", "Auto correction polluted English")
        check(!memory.confirm(heard: "15", spelling: "50", language: .auto, context: ""), "Numeric correction allowed")
        let scoped = PersonalCorrection.validated(heard: "herds", spelling: "Hermes", language: .english, context: "agent")!
        check(PersonalCorrection.apply([scoped], to: "the herds moved", language: .english) == "the herds moved", "Context ignored")
        check(PersonalCorrection.apply([scoped], to: "the agent herds", language: .english) == "the agent Hermes", "Context correction failed")
        let a = PersonalCorrection.validated(heard: "alpha", spelling: "beta", language: .auto, context: "")!
        let b = PersonalCorrection.validated(heard: "beta", spelling: "gamma", language: .auto, context: "")!
        check(PersonalCorrection.apply([a, b], to: "alpha alphabet beta", language: .english) == "beta alphabet gamma", "Cascading/substring replacement")
        let literal = PersonalCorrection.validated(heard: "dollar brand", spelling: "$Brand", language: .english, context: "")!
        check(PersonalCorrection.apply([literal], to: "dollar brand", language: .english) == "$Brand", "Regex replacement interpreted")
        memory.remove(memory.items[0])
        check(PersonalCorrections(fileURL: url).items.isEmpty, "Delete failed")
        let legacy = DictationHistoryItem(id: UUID(), timestamp: now, text: "test", language: "English", appName: "Test", bundleIdentifier: "test", audioDuration: 1, wordCount: 1, cleanupCutCount: nil)
        let legacyData = try JSONEncoder().encode(legacy)
        let decodedLegacy = try JSONDecoder().decode(DictationHistoryItem.self, from: legacyData)
        check(decodedLegacy.rawText == nil, "Legacy history decode")
        check(RecognitionQuality.shouldRecheck(meanLogProbability: -1.4, duration: 5, usedBeamSearch: false), "Missed uncertain segment")
        check(!RecognitionQuality.shouldRecheck(meanLogProbability: -1.4, duration: 20, usedBeamSearch: false), "Unbounded retry")
        check(!RecognitionQuality.shouldRecheck(meanLogProbability: -1.4, duration: 5, usedBeamSearch: true), "Redundant beam retry")
        check(!RecognitionQuality.accepts(original: "take 15 tablets", candidate: "take 50 tablets", originalScore: -1.5, candidateScore: -0.3), "Retry changed number")
        check(!RecognitionQuality.accepts(original: "fifteen tablets", candidate: "fifty tablets", originalScore: -1.5, candidateScore: -0.3), "Retry changed spoken number")
        check(!RecognitionQuality.accepts(original: "петнадесет таблетки", candidate: "петдесет таблетки", originalScore: -1.5, candidateScore: -0.3), "Retry changed Bulgarian number")
        check(!RecognitionQuality.accepts(original: "a b c", candidate: "a b c a b c", originalScore: -1.5, candidateScore: -0.3), "Retry repeated text")
        check(RecognitionQuality.accepts(original: "about diclo fenac", candidate: "about diclofenac", originalScore: -1.5, candidateScore: -0.5), "Good retry rejected")
        print("PASS: \(checks) recognition, correction, persistence and retry checks")
    }
}
