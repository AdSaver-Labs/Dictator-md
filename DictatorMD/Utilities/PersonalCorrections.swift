import Foundation

struct PersonalCorrection: Identifiable, Codable, Equatable {
    var id: String { language + ":" + heard.lowercased() + ":" + context.lowercased() }
    let heard: String
    let spelling: String
    let language: String
    let context: String
    let confirmedAt: Date

    func applies(to text: String, language requested: AppSettings.DictationLanguage) -> Bool {
        (language == AppSettings.DictationLanguage.auto.rawValue || language == requested.rawValue)
            && RecognitionVocabulary.allows(spelling, language: requested)
            && (context.isEmpty || text.localizedCaseInsensitiveContains(context))
    }

    static func validated(heard: String, spelling: String, language: AppSettings.DictationLanguage, context: String) -> PersonalCorrection? {
        let heard = heard.trimmingCharacters(in: .whitespacesAndNewlines)
        let spelling = spelling.trimmingCharacters(in: .whitespacesAndNewlines)
        let context = context.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !heard.isEmpty, !spelling.isEmpty, heard != spelling,
              heard.count <= 80, spelling.count <= 80, context.count <= 120,
              !heard.contains(where: \.isNumber), !spelling.contains(where: \.isNumber),
              RecognitionVocabulary.allows(spelling, language: language),
              !heard.contains("\n"), !spelling.contains("\n") else { return nil }
        return PersonalCorrection(heard: heard, spelling: spelling, language: language.rawValue,
                                  context: context, confirmedAt: Date())
    }

    static func apply(_ corrections: [PersonalCorrection], to text: String, language: AppSettings.DictationLanguage) -> String {
        struct Replacement { let range: NSRange; let text: String }
        var replacements: [Replacement] = []
        let fullRange = NSRange(text.startIndex..., in: text)
        // Match against the original text once: rules cannot cascade or rewrite substrings.
        let ordered = corrections.sorted {
            if $0.heard.count != $1.heard.count { return $0.heard.count > $1.heard.count }
            if $0.context.isEmpty != $1.context.isEmpty { return !$0.context.isEmpty }
            return $0.confirmedAt > $1.confirmedAt
        }
        for correction in ordered where correction.applies(to: text, language: language) {
            let words = correction.heard.split(whereSeparator: \.isWhitespace)
            let literal = words.map { NSRegularExpression.escapedPattern(for: String($0)) }.joined(separator: "\\s+")
            guard let regex = try? NSRegularExpression(pattern: "(?<![\\p{L}\\p{N}_])\(literal)(?![\\p{L}\\p{N}_])", options: [.caseInsensitive]) else { continue }
            for match in regex.matches(in: text, range: fullRange) {
                guard !replacements.contains(where: { NSIntersectionRange($0.range, match.range).length > 0 }) else { continue }
                replacements.append(Replacement(range: match.range, text: correction.spelling))
            }
        }
        let result = NSMutableString(string: text)
        for replacement in replacements.sorted(by: { $0.range.location > $1.range.location }) {
            result.replaceCharacters(in: replacement.range, with: replacement.text)
        }
        return result as String
    }
}

/// Only explicit user confirmations are persisted. No audio or external field edits are collected.
final class PersonalCorrections: ObservableObject, @unchecked Sendable {
    static nonisolated(unsafe) let shared = PersonalCorrections()
    @Published private(set) var items: [PersonalCorrection] = []
    @Published private(set) var error: String?
    private let fileURL: URL

    init(fileURL: URL = AppPaths.supportDirectory().appendingPathComponent("corrections.json")) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([PersonalCorrection].self, from: data) {
            items = decoded.filter { PersonalCorrection.validated(heard: $0.heard, spelling: $0.spelling,
                language: AppSettings.DictationLanguage(rawValue: $0.language) ?? .auto, context: $0.context) != nil }
        }
    }

    @discardableResult
    func confirm(heard: String, spelling: String, language: AppSettings.DictationLanguage, context: String) -> Bool {
        guard let correction = PersonalCorrection.validated(heard: heard, spelling: spelling, language: language, context: context) else {
            error = "Use two different words or short phrases, without numbers (maximum 80 characters)."
            return false
        }
        var updated = items.filter { $0.id != correction.id }
        updated.insert(correction, at: 0)
        return persist(Array(updated.prefix(500)))
    }

    func remove(_ correction: PersonalCorrection) {
        _ = persist(items.filter { $0.id != correction.id })
    }

    private func persist(_ updated: [PersonalCorrection]) -> Bool {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(updated).write(to: fileURL, options: .atomic)
            items = updated
            error = nil
            return true
        } catch {
            self.error = "Could not save the correction on this Mac."
            return false
        }
    }
}
