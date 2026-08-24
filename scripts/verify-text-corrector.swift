import Foundation

@main
struct TextCorrectorSmoke {
    static func main() {
        let settings = AppSettings.shared
        settings.grammarCorrectionEnabled = true
        settings.numberConversionEnabled = true
        settings.localProofreadingEnabled = true

        let corrector = TextCorrector.shared
        let prose = corrector.correct("I have two ideas")
        let version = corrector.correct("version two")
        let measurement = corrector.correct("five minutes")
        let largeCount = corrector.correct("twelve people")
        let money = corrector.correct("three hundred dollars")
        let sequence = corrector.correct("two four six eight")
        let punctuation = corrector.correct("two, three ideas")
        let bulgarianSpelling = corrector.correct("вобще сегаа многоо")
        let bulgarianSpacing = corrector.correct("неискам и немога")
        let bulgarianSlang = corrector.correct("щото кво някъв промпт")
        let bulgarianQuestion = corrector.correct("Как можем да го направим")
        let checks: [(String, () -> Bool)] = [
            ("small prose count", { prose.contains("two ideas") }),
            ("technical number", { version.lowercased().contains("version 2") }),
            ("measurement", { measurement.contains("5 minutes") }),
            ("large count", { largeCount.contains("12 people") }),
            ("money", { money.contains("300 dollars") }),
            ("digit sequence", { sequence.contains("2,468") }),
            ("punctuation boundary", { punctuation.lowercased().contains("two, three ideas") }),
            ("Bulgarian spelling", { bulgarianSpelling.lowercased().contains("въобще") && bulgarianSpelling.contains("сега") && bulgarianSpelling.contains("много") }),
            ("Bulgarian spacing", { bulgarianSpacing.contains("Не искам") && bulgarianSpacing.contains("не мога") }),
            ("Bulgarian slang", { bulgarianSlang.lowercased().contains("щото кво някъв промпт") }),
            ("Bulgarian question", { bulgarianQuestion.hasSuffix("?") })
        ]

        let failed = checks.compactMap { name, check in check() ? nil : name }
        guard failed.isEmpty else {
            fputs("Text correction smoke test failed: \(failed.joined(separator: ", "))\n", stderr)
            fputs("Outputs: \([prose, version, measurement, largeCount, money, sequence, punctuation, bulgarianSpelling, bulgarianSpacing, bulgarianSlang, bulgarianQuestion].joined(separator: " | "))\n", stderr)
            exit(1)
        }
        print("Text correction smoke test passed.")
    }
}
