#include "TextInjector.h"

#include <cstring>
#include <windows.h>

bool TextInjector::insertText(const FocusTarget& target, const std::wstring& text) const {
    if (text.empty()) {
        return false;
    }

    if (!putUnicodeTextOnClipboard(text)) {
        return false;
    }

    if (target.foregroundWindow) {
        SetForegroundWindow(target.foregroundWindow);
    }
    if (target.focusedControl) {
        SetFocus(target.focusedControl);
    }

    sendPasteShortcut();
    return true;
}

bool TextInjector::putUnicodeTextOnClipboard(const std::wstring& text) {
    if (!OpenClipboard(nullptr)) {
        return false;
    }

    EmptyClipboard();

    const size_t bytes = (text.size() + 1) * sizeof(wchar_t);
    HGLOBAL memory = GlobalAlloc(GMEM_MOVEABLE, bytes);
    if (!memory) {
        CloseClipboard();
        return false;
    }

    void* locked = GlobalLock(memory);
    if (!locked) {
        GlobalFree(memory);
        CloseClipboard();
        return false;
    }

    std::memcpy(locked, text.c_str(), bytes);
    GlobalUnlock(memory);

    if (!SetClipboardData(CF_UNICODETEXT, memory)) {
        GlobalFree(memory);
        CloseClipboard();
        return false;
    }

    CloseClipboard();
    return true;
}

void TextInjector::sendPasteShortcut() {
    INPUT inputs[4] = {};

    inputs[0].type = INPUT_KEYBOARD;
    inputs[0].ki.wVk = VK_CONTROL;

    inputs[1].type = INPUT_KEYBOARD;
    inputs[1].ki.wVk = 'V';

    inputs[2].type = INPUT_KEYBOARD;
    inputs[2].ki.wVk = 'V';
    inputs[2].ki.dwFlags = KEYEVENTF_KEYUP;

    inputs[3].type = INPUT_KEYBOARD;
    inputs[3].ki.wVk = VK_CONTROL;
    inputs[3].ki.dwFlags = KEYEVENTF_KEYUP;

    SendInput(4, inputs, sizeof(INPUT));
}
