package app.dictatormd.mobile

import android.inputmethodservice.InputMethodService
import android.view.View
import android.widget.Button
import android.widget.LinearLayout

class DictatorKeyboardService : InputMethodService() {
    private lateinit var store: SharedStore

    override fun onCreate() {
        super.onCreate()
        store = SharedStore(this)
    }

    override fun onCreateInputView(): View {
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(12, 12, 12, 12)
        }

        val insert = Button(this).apply {
            text = "Insert Last"
            setOnClickListener {
                val text = store.latestText().ifBlank { "Dictator-md Android insertion test." }
                currentInputConnection?.commitText(text, 1)
            }
        }

        val test = Button(this).apply {
            text = "Test"
            setOnClickListener {
                currentInputConnection?.commitText("Dictator-md Android insertion test.", 1)
            }
        }

        layout.addView(insert)
        layout.addView(test)
        return layout
    }
}

