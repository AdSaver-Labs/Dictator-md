package app.dictatormd.mobile

import android.app.Activity
import android.os.Bundle
import android.provider.Settings
import android.view.inputmethod.InputMethodManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class MainActivity : Activity() {
    private lateinit var store: SharedStore

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        store = SharedStore(this)

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(32, 32, 32, 32)
        }

        val title = TextView(this).apply {
            text = "Dictator-md"
            textSize = 26f
        }

        val subtitle = TextView(this).apply {
            text = "Android preview. Enable the Dictator-md keyboard, then use it in any text box Android allows."
            textSize = 14f
        }

        val saveTest = Button(this).apply {
            text = "Save Test Dictation"
            setOnClickListener {
                store.recordPlaceholder("Dictator-md Android insertion test.")
            }
        }

        val openKeyboardSettings = Button(this).apply {
            text = "Open Keyboard Settings"
            setOnClickListener {
                startActivity(android.content.Intent(Settings.ACTION_INPUT_METHOD_SETTINGS))
            }
        }

        val chooseKeyboard = Button(this).apply {
            text = "Choose Keyboard"
            setOnClickListener {
                getSystemService(InputMethodManager::class.java).showInputMethodPicker()
            }
        }

        layout.addView(title)
        layout.addView(subtitle)
        layout.addView(saveTest)
        layout.addView(openKeyboardSettings)
        layout.addView(chooseKeyboard)
        setContentView(layout)
    }
}

