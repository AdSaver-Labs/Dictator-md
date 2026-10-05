import Foundation

@main
struct TextCorrectorSmoke {
    static func main() {
        let settings = AppSettings.shared
        let originalHesitationSetting = settings.removeHesitationSounds
        defer { settings.removeHesitationSounds = originalHesitationSetting }
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
        let cityCyrillic = corrector.correct("Отивам в Благоевграт утре", language: .bulgarian)
        let citySeparated = corrector.correct("Благоев град е хубав", language: .bulgarian)
        let cityLatin = corrector.correct("Błagojef Rat", language: .bulgarian)
        let cityCorrect = corrector.correct("Благоевград и Велико Търново", language: .bulgarian)
        let colloquial = corrector.correct("Днеска нема да ходя", language: .bulgarian)
        let englishControl = corrector.correct("Blagoevgrad is a city", language: .english)
        settings.removeHesitationSounds = true
        let preservedMeaning = corrector.correct("I mean you know this matters", style: .polished, language: .english)
        let cleanedHesitation = corrector.correct("Um this matters", style: .polished, language: .english)
        let preservedBulgarianMeaning = corrector.correct("Ами значи това е важно", style: .polished, language: .bulgarian)
        let personal = PersonalCorrection.validated(heard: "дикло фенак", spelling: "диклофенак", language: .bulgarian, context: "")!
        let personalStandard = corrector.correct("питам за дикло фенак", style: .standard, language: .bulgarian, corrections: [personal])
        let personalRaw = corrector.correct("дикло фенак", style: .raw, language: .bulgarian, corrections: [personal])
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
            ("Bulgarian question", { bulgarianQuestion.hasSuffix("?") }),
            ("Bulgarian city lexicon loaded", { BulgarianPlaceNames.cityCount >= 200 }),
            ("Bulgarian city typo", { cityCyrillic.contains("Благоевград") }),
            ("Bulgarian city spacing", { citySeparated.contains("Благоевград") }),
            ("Bulgarian city transliteration", { cityLatin.contains("Благоевград") }),
            ("Bulgarian city protected", { cityCorrect.contains("Благоевград") && cityCorrect.contains("Велико Търново") }),
            ("Bulgarian colloquial protected", { colloquial.lowercased().contains("днеска нема") }),
            ("English text unchanged", { englishControl.contains("Blagoevgrad") }),
            ("meaningful English phrases preserved", { preservedMeaning.lowercased().contains("i mean you know") }),
            ("hesitation sounds removable", { !cleanedHesitation.lowercased().contains("um ") }),
            ("meaningful Bulgarian phrases preserved", { preservedBulgarianMeaning.lowercased().contains("ами значи") }),
            ("confirmed correction in formatting pipeline", { personalStandard.contains("диклофенак") }),
            ("raw output remains raw", { personalRaw == "дикло фенак" })
        ]

        let failed = checks.compactMap { name, check in check() ? nil : name }
        guard failed.isEmpty else {
            fputs("Text correction smoke test failed: \(failed.joined(separator: ", "))\n", stderr)
            fputs("Outputs: \([prose, version, measurement, largeCount, money, sequence, punctuation, bulgarianSpelling, bulgarianSpacing, bulgarianSlang, bulgarianQuestion, cityCyrillic, citySeparated, cityLatin, cityCorrect, colloquial, englishControl].joined(separator: " | "))\n", stderr)
            exit(1)
        }
        print("Text correction smoke test passed.")
    }
}
