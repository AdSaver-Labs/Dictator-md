#include "TrayIcon.h"

#include "WindowsIds.h"

bool TrayIcon::create(HWND window, HINSTANCE instance) {
    data_ = {};
    data_.cbSize = sizeof(data_);
    data_.hWnd = window;
    data_.uID = 1;
    data_.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
    data_.uCallbackMessage = WM_DICTATOR_TRAY;
    (void)instance;
    data_.hIcon = LoadIconW(nullptr, IDI_APPLICATION);
    wcscpy_s(data_.szTip, L"Dictator-md");

    menu_ = CreatePopupMenu();
    if (!menu_) {
        return false;
    }

    AppendMenuW(menu_, MF_STRING, IDM_DICTATOR_TEST_INSERT, L"Test insert");
    AppendMenuW(menu_, MF_SEPARATOR, 0, nullptr);
    AppendMenuW(menu_, MF_STRING, IDM_DICTATOR_EXIT, L"Exit");

    return Shell_NotifyIconW(NIM_ADD, &data_) != 0;
}

void TrayIcon::showMenu(HWND window) const {
    if (!menu_) {
        return;
    }

    POINT cursor;
    GetCursorPos(&cursor);
    SetForegroundWindow(window);
    TrackPopupMenu(menu_, TPM_RIGHTBUTTON, cursor.x, cursor.y, 0, window, nullptr);
}

void TrayIcon::destroy() {
    if (data_.hWnd) {
        Shell_NotifyIconW(NIM_DELETE, &data_);
    }
    if (menu_) {
        DestroyMenu(menu_);
        menu_ = nullptr;
    }
}
