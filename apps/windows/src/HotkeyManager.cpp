#include "HotkeyManager.h"

#include "WindowsIds.h"

bool HotkeyManager::registerRightAlt(HWND window) {
    return registerCandidate(window, {0, VK_RMENU, L"Right Alt"});
}

bool HotkeyManager::registerF8(HWND window) {
    return registerCandidate(window, {0, VK_F8, L"F8"});
}

bool HotkeyManager::registerCtrlAltSpace(HWND window) {
    return registerCandidate(window, {MOD_CONTROL | MOD_ALT, VK_SPACE, L"Ctrl+Alt+Space"});
}

bool HotkeyManager::registerCandidate(HWND window, const Candidate& candidate) {
    unregister(window);
    if (RegisterHotKey(window, ID_DICTATOR_HOTKEY, candidate.modifiers, candidate.virtualKey) == 0) {
        return false;
    }

    registered_ = true;
    usedFallback_ = false;
    activeHotkeyLabel_ = candidate.label;
    return true;
}

void HotkeyManager::unregister(HWND window) {
    if (!registered_) {
        return;
    }

    UnregisterHotKey(window, ID_DICTATOR_HOTKEY);
    registered_ = false;
    usedFallback_ = false;
    activeHotkeyLabel_.clear();
}
