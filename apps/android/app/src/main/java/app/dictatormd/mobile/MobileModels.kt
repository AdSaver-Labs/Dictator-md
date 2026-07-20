package app.dictatormd.mobile

import java.time.Instant
import java.util.UUID

enum class MobileLanguageMode(val wireValue: String) {
    Auto("auto"),
    English("en"),
    Bulgarian("bg")
}

data class MobileDictationEvent(
    val version: Int = 1,
    val id: String = UUID.randomUUID().toString(),
    val timestamp: String = Instant.now().toString(),
    val platform: String = "android",
    val language: MobileLanguageMode = MobileLanguageMode.Auto,
    val text: String,
    val wordCount: Int = text.trim().split(Regex("\\s+")).filter { it.isNotBlank() }.size,
    val audioDuration: Double = 0.0,
    val cleanupCutCount: Int = 0
)

data class MobileUserProfile(
    val version: Int = 1,
    val languageMode: MobileLanguageMode = MobileLanguageMode.Auto,
    val customTerms: List<String> = listOf("Openclaw", "Hermes"),
    val grammarCorrection: Boolean = true,
    val numberConversion: Boolean = true,
    val intonationFormatting: Boolean = false,
    val duplicateCollapse: Boolean = true
)

