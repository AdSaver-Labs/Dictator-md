package app.dictatormd.mobile

import android.content.Context

class SharedStore(context: Context) {
    private val preferences = context.getSharedPreferences("dictator-md-mobile", Context.MODE_PRIVATE)

    fun latestText(): String {
        return preferences.getString("latestText", null).orEmpty()
    }

    fun recordPlaceholder(text: String) {
        preferences.edit()
            .putString("latestText", text)
            .putLong("latestTimestamp", System.currentTimeMillis())
            .apply()
    }

    fun languageMode(): MobileLanguageMode {
        return when (preferences.getString("languageMode", "auto")) {
            "en" -> MobileLanguageMode.English
            "bg" -> MobileLanguageMode.Bulgarian
            else -> MobileLanguageMode.Auto
        }
    }
}

