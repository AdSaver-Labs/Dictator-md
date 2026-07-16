#pragma once

#include <windows.h>
#include <string>

class HotkeyManager {
public:
    bool registerDefault(HWND window);
    void unregister(HWND window);
    const std::wstring& activeHotkeyLabel() const { return activeHotkeyLabel_; }
    bool usedFallback() const { return usedFallback_; }

private:
    struct Candidate {
        UINT modifiers;
        UINT virtualKey;
        const wchar_t* label;
    };

    bool registered_ = false;
    bool usedFallback_ = false;
    std::wstring activeHotkeyLabel_;
};
