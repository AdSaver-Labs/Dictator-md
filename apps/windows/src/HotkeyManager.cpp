#include "HotkeyManager.h"

#include "WindowsIds.h"

#include <cstddef>
#include <array>

bool HotkeyManager::registerDefault(HWND window) {
    if (registered_) {
        return true;
    }

    constexpr std::array<Candidate, 3> candidates = {{
        {0, VK_RMENU, L"Right Alt"},
        {0, VK_F8, L"F8"},
        {MOD_CONTROL | MOD_ALT, VK_SPACE, L"Ctrl+Alt+Space"},
    }};

    for (std::size_t index = 0; index < candidates.size(); ++index) {
        const auto& candidate = candidates[index];
        if (RegisterHotKey(window, ID_DICTATOR_HOTKEY, candidate.modifiers, candidate.virtualKey) != 0) {
            registered_ = true;
            usedFallback_ = index > 0;
            activeHotkeyLabel_ = candidate.label;
            return true;
        }
    }

    activeHotkeyLabel_.clear();
    usedFallback_ = false;
    registered_ = false;
    return false;
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
