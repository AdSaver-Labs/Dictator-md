#pragma once

#include <windows.h>

class HotkeyManager {
public:
    bool registerDefault(HWND window);
    void unregister(HWND window);

private:
    bool registered_ = false;
};
