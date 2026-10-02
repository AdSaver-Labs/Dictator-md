import Foundation

/// Offline spelling hints for Bulgarian city names. The full list protects
/// recognized names; only observed, unambiguous ASR variants are rewritten.
enum BulgarianPlaceNames {
    private static let names: [String] = {
        let url = Bundle.main.url(forResource: "BulgarianCities", withExtension: "json")
            ?? URL(fileURLWithPath: "DictatorMD/Resources/BulgarianCities.json")
        guard let data = try? Data(contentsOf: url),
              let names = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return names
    }()

    private static let cityPattern: NSRegularExpression? = {
        let alternatives = names.sorted { $0.count > $1.count }
            .map(NSRegularExpression.escapedPattern(for:))
            .joined(separator: "|")
        guard !alternatives.isEmpty else { return nil }
        return try? NSRegularExpression(
            pattern: "(?<![\\p{L}\\p{N}])(?:\(alternatives))(?![\\p{L}\\p{N}])",
            options: [.caseInsensitive]
        )
    }()

    static var cityCount: Int { names.count }

    static func protectedRanges(in text: String) -> [NSRange] {
        cityPattern?.matches(in: text, range: NSRange(text.startIndex..., in: text)).map(\.range) ?? []
    }

    static func correctObservedMishearings(_ text: String) -> String {
        let variants = [
            "Благоев град", "Благоеврат", "Благоевграт", "Благойевград",
            "Blagoevgrad", "Blagoyevgrad", "Blagoev rat", "Błagojef Rat"
        ]
        let alternatives = variants.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
        guard let pattern = try? NSRegularExpression(
            pattern: "(?<![\\p{L}\\p{N}])(?:\(alternatives))(?![\\p{L}\\p{N}])",
            options: [.caseInsensitive]
        ) else { return text }
        return pattern.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: "Благоевград"
        )
    }
}
