#include "HotkeyManager.h"

#include "WindowsIds.h"

bool HotkeyManager::registerDefault(HWND window) {
    if (registered_) {
        return true;
    }

    registered_ = RegisterHotKey(window, ID_DICTATOR_HOTKEY, 0, VK_RMENU) != 0;
    return registered_;
}

void HotkeyManager::unregister(HWND window) {
    if (!registered_) {
        return;
    }

    UnregisterHotKey(window, ID_DICTATOR_HOTKEY);
    registered_ = false;
}
