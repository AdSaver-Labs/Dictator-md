import Foundation

final class MobileSharedStore: ObservableObject {
    @Published private(set) var events: [MobileDictationEvent] = []
    @Published var profile = MobileUserProfile()

    private let appGroupId = "group.com.dictatormd.shared"
    private let eventsKey = "dictator-md.mobile.events"
    private let profileKey = "dictator-md.mobile.profile"

    private var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupId) ?? .standard
    }

    init() {
        load()
    }

    func record(text: String, language: MobileLanguageMode) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let event = MobileDictationEvent(platform: .iOS, language: language, text: trimmed)
        events.insert(event, at: 0)
        save()
    }

    func latestText() -> String {
        events.first?.text ?? ""
    }

    private func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let data = defaults.data(forKey: eventsKey),
           let decoded = try? decoder.decode([MobileDictationEvent].self, from: data) {
            events = decoded
        }

        if let data = defaults.data(forKey: profileKey),
           let decoded = try? decoder.decode(MobileUserProfile.self, from: data) {
            profile = decoded
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        defaults.set(try? encoder.encode(events), forKey: eventsKey)
        defaults.set(try? encoder.encode(profile), forKey: profileKey)
    }
}

