#pragma once

#include <windows.h>
#include <string>

class HotkeyManager {
public:
    bool registerRightAlt(HWND window);
    bool registerF8(HWND window);
    bool registerCtrlAltSpace(HWND window);
    void unregister(HWND window);
    const std::wstring& activeHotkeyLabel() const { return activeHotkeyLabel_; }
    bool usedFallback() const { return usedFallback_; }

private:
    struct Candidate {
        UINT modifiers;
        UINT virtualKey;
        const wchar_t* label;
    };

    bool registerCandidate(HWND window, const Candidate& candidate);

    bool registered_ = false;
    bool usedFallback_ = false;
    std::wstring activeHotkeyLabel_;
};
