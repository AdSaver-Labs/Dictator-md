import Foundation

enum RecognitionQuality {
    static func shouldRecheck(meanLogProbability: Double, duration: Double, usedBeamSearch: Bool) -> Bool {
        !usedBeamSearch && duration >= 1 && duration <= 12 && meanLogProbability.isFinite && meanLogProbability < -1.0
    }

    static func accepts(original: String, candidate: String, originalScore: Double, candidateScore: Double) -> Bool {
        guard candidateScore.isFinite, candidateScore > originalScore + 0.2,
              !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let before = original.split(whereSeparator: \.isWhitespace).count
        let after = candidate.split(whereSeparator: \.isWhitespace).count
        guard after >= max(1, before / 2), after <= max(before + 3, Int(Double(before) * 1.4)) else { return false }
        // Never accept a confidence-based retry that changes an explicit numeric value.
        let numbers: (String) -> [String] = { text in
            let regex = try! NSRegularExpression(pattern: "\\p{N}+(?:[.,]\\p{N}+)*")
            let nsText = text as NSString
            return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { nsText.substring(with: $0.range) }
        }
        guard numbers(original) == numbers(candidate) else { return false }
        let numberWords = Set("zero one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty thirty forty fifty sixty seventy eighty ninety hundred thousand million нула един една едно два две три четири пет шест седем осем девет десет единадесет дванадесет тринадесет четиринадесет петнадесет шестнадесет седемнадесет осемнадесет деветнадесет двадесет тридесет четиридесет петдесет шестдесет седемдесет осемдесет деветдесет сто двеста триста хиляда милион".split(separator: " ").map(String.init))
        let spokenNumbers: (String) -> [String] = { text in
            text.lowercased().components(separatedBy: CharacterSet.letters.inverted).filter { numberWords.contains($0) }
        }
        guard spokenNumbers(original) == spokenNumbers(candidate) else { return false }
        let words = candidate.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        if words.count >= 6 {
            for index in 0...(words.count - 6) where Array(words[index..<(index + 3)]) == Array(words[(index + 3)..<(index + 6)]) {
                return false
            }
        }
        return true
    }
}
