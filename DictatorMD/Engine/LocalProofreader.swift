import AppKit
import Foundation

/// Conservative on-device spelling cleanup. This intentionally avoids sending
/// dictated text to a service and leaves code, custom vocabulary, and names alone.
final class LocalProofreader: @unchecked Sendable {
    static let shared = LocalProofreader()

    private init() {}

    func proofread(_ text: String, language: AppSettings.DictationLanguage, protectedTerms: [String]) -> String {
        guard let spellLanguage = spellLanguage(for: text, requestedLanguage: language) else { return text }

        let work = {
            let checker = NSSpellChecker.shared
            let protectedWords = Set(protectedTerms.map { $0.lowercased() })
            let pattern = #"\b[\p{L}][\p{L}'-]{2,}\b"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }

            var result = text
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            let protectedCityRanges = spellLanguage.lowercased().hasPrefix("bg")
                ? BulgarianPlaceNames.protectedRanges(in: text) : []
            for match in matches.reversed() {
                guard !protectedCityRanges.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) else {
                    continue
                }
                guard let range = Range(match.range, in: result) else { continue }
                let word = String(result[range])
                guard self.shouldCheck(word, protectedWords: protectedWords, language: spellLanguage) else { continue }

                let misspelling = checker.checkSpelling(
                    of: word,
                    startingAt: 0,
                    language: spellLanguage,
                    wrap: false,
                    inSpellDocumentWithTag: 0,
                    wordCount: nil
                )
                let wordRange = NSRange(location: 0, length: (word as NSString).length)
                guard misspelling.location == 0, misspelling.length == wordRange.length,
                      let suggestions = checker.guesses(
                        forWordRange: wordRange,
                        in: word,
                        language: spellLanguage,
                        inSpellDocumentWithTag: 0
                      ),
                      let suggestion = self.bestSuggestion(from: suggestions, for: word),
                      self.shouldApply(suggestion: suggestion, to: word) else {
                    continue
                }
                result.replaceSubrange(range, with: self.preserveCapitalization(of: word, in: suggestion))
            }
            return result
        }

        // NSSpellChecker is AppKit state. Dictation correction runs off the main
        // thread, so marshal the small spell-check pass safely to the main queue.
        if Thread.isMainThread { return work() }
        return DispatchQueue.main.sync(execute: work)
    }

    private func spellLanguage(for text: String, requestedLanguage: AppSettings.DictationLanguage) -> String? {
        let available = NSSpellChecker.shared.availableLanguages
        let prefix: String
        switch requestedLanguage {
        case .english:
            prefix = "en"
        case .bulgarian:
            prefix = "bg"
        case .auto:
            prefix = containsCyrillic(text) ? "bg" : "en"
        }
        return available.first { $0.lowercased().hasPrefix(prefix) }
    }

    private func containsCyrillic(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x0400...0x052F).contains(scalar.value)
        }
    }

    private func shouldCheck(_ word: String, protectedWords: Set<String>, language: String) -> Bool {
        guard !protectedWords.contains(word.lowercased()),
              !(language.lowercased().hasPrefix("bg") && BulgarianTextCorrector.isProtectedSlang(word)),
              word.rangeOfCharacter(from: .decimalDigits) == nil,
              !word.contains("-"),
              !word.contains("'"),
              word != word.uppercased(),
              word.count >= 4 else {
            return false
        }
        // Capitalized internal words are normally names or product terms.
        return word == word.lowercased() || word == word.capitalized
    }

    private func shouldApply(suggestion: String, to word: String) -> Bool {
        guard !suggestion.isEmpty,
              suggestion.lowercased() != word.lowercased(),
              suggestion.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            return false
        }
        return editDistance(word.lowercased(), suggestion.lowercased()) <= 2
    }

    private func bestSuggestion(from suggestions: [String], for word: String) -> String? {
        suggestions
            .filter { shouldApply(suggestion: $0, to: word) }
            .min { left, right in
                let leftDistance = editDistance(word.lowercased(), left.lowercased())
                let rightDistance = editDistance(word.lowercased(), right.lowercased())
                if leftDistance != rightDistance { return leftDistance < rightDistance }
                return left.count < right.count
            }
    }

    private func preserveCapitalization(of original: String, in suggestion: String) -> String {
        original.first?.isUppercase == true ? suggestion.capitalized : suggestion
    }

    private func editDistance(_ source: String, _ target: String) -> Int {
        let sourceChars = Array(source)
        let targetChars = Array(target)
        var previous = Array(0...targetChars.count)

        for (sourceIndex, sourceChar) in sourceChars.enumerated() {
            var current = [sourceIndex + 1]
            for (targetIndex, targetChar) in targetChars.enumerated() {
                let substitution = previous[targetIndex] + (sourceChar == targetChar ? 0 : 1)
                current.append(min(current[targetIndex] + 1, previous[targetIndex + 1] + 1, substitution))
            }
            previous = current
        }
        return previous.last ?? 0
    }
}
