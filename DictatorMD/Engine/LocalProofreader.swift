import AppKit
import Foundation

/// Conservative on-device spelling cleanup. This intentionally avoids sending
/// dictated text to a service and leaves code, custom vocabulary, and names alone.
final class LocalProofreader: @unchecked Sendable {
    static let shared = LocalProofreader()

    private init() {}

    func proofread(_ text: String, language: AppSettings.DictationLanguage, protectedTerms: [String]) -> String {
        let work = {
            guard let spellLanguage = self.spellLanguage(for: text, requestedLanguage: language) else { return text }
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
                      let suggestion = checker.correction(
                        forWordRange: wordRange,
                        in: word,
                        language: spellLanguage,
                        inSpellDocumentWithTag: 0
                      ),
                      Self.isSafeAutomaticCorrection(suggestion, for: word, language: spellLanguage) else {
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

    static func isSafeAutomaticCorrection(_ suggestion: String, for word: String, language: String) -> Bool {
        guard !suggestion.isEmpty,
              suggestion.lowercased() != word.lowercased(),
              suggestion.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              suggestion.allSatisfy(\.isLetter), word.allSatisfy(\.isLetter) else {
            return false
        }
        if language.lowercased().hasPrefix("bg") {
            // A nearby dictionary word is not evidence of the intended Bulgarian
            // verb/name. Allow only a system-approved duplicated-letter removal;
            // semantic substitutions belong to explicit personal corrections.
            let source = Array(word.lowercased())
            let target = Array(suggestion.lowercased())
            guard source.count == target.count + 1 else { return false }
            for index in source.indices where index > 0 && source[index] == source[index - 1] {
                var candidate = source
                candidate.remove(at: index)
                if candidate == target { return true }
            }
            return false
        }
        guard !RecognitionVocabulary.containsCyrillic(suggestion) else { return false }
        return editDistance(word.lowercased(), suggestion.lowercased()) <= 1
    }

    private func preserveCapitalization(of original: String, in suggestion: String) -> String {
        original.first?.isUppercase == true ? suggestion.capitalized : suggestion
    }

    private static func editDistance(_ source: String, _ target: String) -> Int {
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
