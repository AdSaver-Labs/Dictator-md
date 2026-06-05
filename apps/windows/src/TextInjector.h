#pragma once

#include "FocusTracker.h"

#include <string>

class TextInjector {
public:
    bool insertText(const FocusTarget& target, const std::wstring& text) const;

private:
    static bool putUnicodeTextOnClipboard(const std::wstring& text);
    static void sendPasteShortcut();
};
