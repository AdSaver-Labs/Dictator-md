#pragma once

#include <shellapi.h>
#include <windows.h>

class TrayIcon {
public:
    bool create(HWND window, HINSTANCE instance);
    void showMenu(HWND window) const;
    void destroy();

private:
    NOTIFYICONDATAW data_ = {};
    HMENU menu_ = nullptr;
};
