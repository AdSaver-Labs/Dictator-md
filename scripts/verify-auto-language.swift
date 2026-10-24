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
            (.nan, 0.8, "bg", true, nil)
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
        print("Auto language decision passed (\(cases.count) cases).")
    }
}
