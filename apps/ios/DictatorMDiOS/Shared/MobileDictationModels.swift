import Foundation

enum MobilePlatform: String, Codable {
    case iOS = "ios"
    case android
}

enum MobileLanguageMode: String, Codable, CaseIterable {
    case automatic = "auto"
    case english = "en"
    case bulgarian = "bg"

    var displayName: String {
        switch self {
        case .automatic: return "Auto"
        case .english: return "English"
        case .bulgarian: return "Bulgarian"
        }
    }
}

struct MobileDictationEvent: Identifiable, Codable, Equatable {
    var version = 1
    let id: UUID
    let timestamp: Date
    let platform: MobilePlatform
    let language: MobileLanguageMode
    let text: String
    let wordCount: Int
    let audioDuration: Double
    let cleanupCutCount: Int

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        platform: MobilePlatform,
        language: MobileLanguageMode,
        text: String,
        audioDuration: Double = 0,
        cleanupCutCount: Int = 0
    ) {
        self.id = id
        self.timestamp = timestamp
        self.platform = platform
        self.language = language
        self.text = text
        self.wordCount = text.split { $0.isWhitespace || $0.isNewline }.count
        self.audioDuration = audioDuration
        self.cleanupCutCount = cleanupCutCount
    }
}

struct MobileUserProfile: Codable, Equatable {
    var version = 1
    var languageMode: MobileLanguageMode = .automatic
    var customTerms: [String] = ["Openclaw", "Hermes"]
    var grammarCorrection = true
    var numberConversion = true
    var intonationFormatting = false
    var duplicateCollapse = true
}

