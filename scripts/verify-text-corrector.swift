import Foundation

@main
struct TextCorrectorSmoke {
    static func main() {
        let settings = AppSettings.shared
        settings.grammarCorrectionEnabled = true
        settings.numberConversionEnabled = true
        settings.localProofreadingEnabled = false

        let corrector = TextCorrector.shared
        let prose = corrector.correct("I have two ideas")
        let version = corrector.correct("version two")
        let measurement = corrector.correct("five minutes")
        let largeCount = corrector.correct("twelve people")
        let money = corrector.correct("three hundred dollars")
        let sequence = corrector.correct("two four six eight")
        let punctuation = corrector.correct("two, three ideas")
        let checks: [(String, () -> Bool)] = [
            ("small prose count", { prose.contains("two ideas") }),
            ("technical number", { version.lowercased().contains("version 2") }),
            ("measurement", { measurement.contains("5 minutes") }),
            ("large count", { largeCount.contains("12 people") }),
            ("money", { money.contains("300 dollars") }),
            ("digit sequence", { sequence.contains("2,468") }),
            ("punctuation boundary", { punctuation.lowercased().contains("two, three ideas") })
        ]

        let failed = checks.compactMap { name, check in check() ? nil : name }
        guard failed.isEmpty else {
            fputs("Text correction smoke test failed: \(failed.joined(separator: ", "))\n", stderr)
            fputs("Outputs: \([prose, version, measurement, largeCount, money, sequence, punctuation].joined(separator: " | "))\n", stderr)
            exit(1)
        }
        print("Text correction smoke test passed.")
    }
}
