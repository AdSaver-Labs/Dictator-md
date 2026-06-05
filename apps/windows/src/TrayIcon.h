#pragma once

#include <windows.h>
#include <shellapi.h>

class TrayIcon {
public:
    bool create(HWND window, HINSTANCE instance);
    void showMenu(HWND window) const;
    void destroy();

private:
    NOTIFYICONDATAW data_ = {};
    HMENU menu_ = nullptr;
};
