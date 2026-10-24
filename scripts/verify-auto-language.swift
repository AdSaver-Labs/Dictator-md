import Foundation

@main
struct AutoLanguageSmoke {
    static func main() {
        let cases: [(Float, Float, String, Bool, AppSettings.DictationLanguage?)] = [
            (0.88, 0.04, "en", true, .english),
            (0.03, 0.81, "bg", true, .bulgarian),
            (0.20, 0.17, "en", true, nil),
            (0.20, 0.17, "en", false, nil),
            (0.08, 0.36, "bg", false, .bulgarian),
            (0.43, 0.07, "en", false, .english),
            (0.02, 0.03, "unknown", false, nil),
            (0.18, 0.001, "pl", true, nil),
            (0.18, 0.001, "pl", false, nil),
            (0.05, 0.002, "ru", false, nil),
            (0.001, 0.001, "sr", false, nil),
            (0.34, 0.11, "en", true, nil),
            (0.34, 0.11, "en", false, .english),
            (0.11, 0.65, "bg", true, .bulgarian),
            (0.65, 0.11, "bg", true, nil),
            (0.18, 0.20, "bg", false, nil),
            (.infinity, 0.8, "en", false, nil),
            (-0.1, 0.8, "bg", false, nil),
            (.nan, 0.8, "bg", true, nil),
            (1.1, 0, "en", false, nil),
            (0.9, 0.9, "en", false, nil),
            (0, 0, "en", false, nil)
        ]
        for (english, bulgarian, topLanguage, strong, expected) in cases {
            let actual = AutoLanguageDecision.choose(
                english: english,
                bulgarian: bulgarian,
                topLanguage: topLanguage,
                requireStrongEvidence: strong
            )
            guard actual == expected else {
                fputs("Auto language decision failed: en=\(english) bg=\(bulgarian) strong=\(strong)\n", stderr)
                exit(1)
            }
        }
        var sampleChecks = 0
        func check(_ condition: Bool, _ label: String) {
            guard condition else { fatalError(label) }
            sampleChecks += 1
        }
        let silence = [Float](repeating: 0, count: 32 * 16000)
        let quiet = (0..<32000).map { Float(sin(Double($0) * 0.08)) * 0.0001 }
        let original = silence + quiet
        let sample = AutoLanguageSample.prepare(original)!
        check(sample.offset == silence.count - 4800, "Leading silence with pre-roll")
        check(original == silence + quiet, "Detection must not alter the decode buffer")
        check(sample.samples.count == quiet.count + 4800, "Whole speech tail kept")
        check(sample.gain == 8, "Quiet detection gain is bounded")
        check(AutoLanguageSample.prepare([]) == nil, "Empty input")
        check(AutoLanguageSample.prepare(silence) == nil, "Silence is not language evidence")
        check(AutoLanguageSample.prepare([.nan, .infinity]) == nil, "Non-finite audio rejected")
        var click = [Float](repeating: 0, count: 16000)
        click[0] = 1
        check(AutoLanguageSample.prepare(click) == nil, "A click is not speech evidence")
        check(AutoLanguageSample.prepare(quiet + [Float](repeating: 0.5, count: 16000))?.offset == 0,
              "Quiet opening before louder speech is retained")
        check(AutoLanguageSample.prepare([Float](repeating: 0.5, count: 45 * 16000))?.samples.count == 30 * 16000,
              "Detection copy bounded to 30 seconds")
        check(AutoLanguageSample.prepare([Float](repeating: 0.5, count: 32000))?.gain == 1,
              "Normal speech is not amplified")
        check(AutoLanguageSample.prepare([Float](repeating: 0, count: 61 * 16000) + quiet) == nil,
              "Onset scan bounded to 60 seconds")
        let now = Date(timeIntervalSince1970: 1)
        let review = LanguageReviewAudio(quiet, now: now)!
        check(review.samples(at: now) == quiet, "Review uses identical samples")
        check(review.samples(at: now.addingTimeInterval(299)) == quiet, "Retry before expiry")
        check(review.samples(at: now.addingTimeInterval(300)) == nil, "No retry at deadline")
        check(review.samples(at: now.addingTimeInterval(400)) == nil, "No retry after expiry")
        check(LanguageReviewAudio([]) == nil, "No empty retention")
        check(LanguageReviewAudio([Float](repeating: 0, count: LanguageReviewAudio.maximumSamples + 1)) == nil,
              "Retention memory is bounded")
        print("Auto language passed (\(cases.count) decision cases, \(sampleChecks) sampling/recovery cases).")
    }
}
