#pragma once

#include "DictationPipeline.h"
#include "FocusTracker.h"
#include "HotkeyManager.h"
#include "TextInjector.h"
#include "TrayIcon.h"

#include <windows.h>

class App {
public:
    App();
    int run(HINSTANCE instance, int showCommand);

private:
    static LRESULT CALLBACK WindowProc(HWND window, UINT message, WPARAM wParam, LPARAM lParam);

    bool createMessageWindow(HINSTANCE instance);
    void onHotkey();
    void onTrayCommand(UINT command);
    void showStatus() const;
    void configureHotkey(UINT command);

    HWND window_ = nullptr;
    HotkeyManager hotkey_;
    TrayIcon tray_;
    FocusTracker focusTracker_;
    DictationPipeline pipeline_;
    TextInjector injector_;
};
