#pragma once

#include <windows.h>
#include <shellapi.h>
#include <string>

class TrayIcon {
public:
    bool create(HWND window, HINSTANCE instance, const std::wstring& hotkeyLabel);
    void showMenu(HWND window) const;
    void destroy();

private:
    NOTIFYICONDATAW data_ = {};
    HMENU menu_ = nullptr;
};
