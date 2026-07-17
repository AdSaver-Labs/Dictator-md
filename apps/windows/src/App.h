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

    bool createMainWindow(HINSTANCE instance, int showCommand);
    void createChildControls();
    void layoutControls(int width, int height);
    void onHotkey();
    void onTrayCommand(UINT command);
    void showStatus();
    void configureHotkey(UINT command);
    void refreshStatusText();

    HWND window_ = nullptr;
    HWND statusLabel_ = nullptr;
    HWND infoLabel_ = nullptr;
    HWND rightAltButton_ = nullptr;
    HWND f8Button_ = nullptr;
    HWND ctrlAltSpaceButton_ = nullptr;
    HWND clearButton_ = nullptr;
    HWND testButton_ = nullptr;
    HWND exitButton_ = nullptr;
    HotkeyManager hotkey_;
    TrayIcon tray_;
    FocusTracker focusTracker_;
    DictationPipeline pipeline_;
    TextInjector injector_;
};
