import Foundation

/// Small, conservative Bulgarian cleanup layer for recurring dictation errors.
/// It handles only unambiguous orthography/spacing cases and deliberately keeps
/// common colloquial Bulgarian intact. Broader spell correction is delegated to
/// the installed macOS Bulgarian dictionary in LocalProofreader.
enum BulgarianTextCorrector {
    private static let protectedSlang: Set<String> = [
        "щото", "щот", "кво", "къв", "ква", "кви", "някъв", "няква", "някви",
        "просто", "май", "нали", "аре", "айде", "бахти", "яко", "кеф", "кефи",
        "ап", "апликация", "сетинги", "шорткът", "хоткий", "промпт", "клауд",
        "бекенд", "фронтенд", "деплой", "репо", "комит", "пушвам", "мерджвам"
    ]

    static func correct(_ text: String) -> String {
        var result = text

        // Frequent speech-to-text fusions where the intended standard Bulgarian
        // form is unambiguous in normal prose.
        let replacements: [(String, String)] = [
            (#"\bнеискам\b"#, "не искам"),
            (#"\bнеиска\b"#, "не иска"),
            (#"\bнеискат\b"#, "не искат"),
            (#"\bнемога\b"#, "не мога"),
            (#"\bнеможеш\b"#, "не можеш"),
            (#"\bнеможе\b"#, "не може"),
            (#"\bнезнам\b"#, "не знам"),
            (#"\bнесъм\b"#, "не съм"),
            (#"\bнеса\b"#, "не са"),
            (#"\bнебеше\b"#, "не беше"),
            (#"\bнеможе да\b"#, "не може да"),
            (#"\bвобще\b"#, "въобще"),
            (#"\bнаистина ли\b"#, "наистина ли")
        ]
        for (pattern, replacement) in replacements {
            result = result.replacingOccurrences(of: pattern, with: replacement, options: [.regularExpression, .caseInsensitive])
        }
        return result
    }

    static func isProtectedSlang(_ word: String) -> Bool {
        protectedSlang.contains(normalize(word))
    }

    private static func normalize(_ word: String) -> String {
        word.lowercased().trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
    }
}
