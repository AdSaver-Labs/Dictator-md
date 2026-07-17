#include "App.h"

#include "WindowsIds.h"

#include <algorithm>
#include <string>

App::App() = default;

int App::run(HINSTANCE instance, int showCommand) {
    if (!createMainWindow(instance, showCommand)) {
        MessageBoxW(nullptr, L"Failed to create Dictator-md window.", L"Dictator-md", MB_ICONERROR);
        return 1;
    }

    tray_.create(window_, instance, hotkey_.activeHotkeyLabel());

    ShowWindow(window_, showCommand == SW_SHOWDEFAULT ? SW_SHOWNORMAL : showCommand);
    UpdateWindow(window_);

    MSG message;
    while (GetMessageW(&message, nullptr, 0, 0) > 0) {
        TranslateMessage(&message);
        DispatchMessageW(&message);
    }

    hotkey_.unregister(window_);
    tray_.destroy();
    return static_cast<int>(message.wParam);
}

bool App::createMainWindow(HINSTANCE instance, int showCommand) {
    constexpr wchar_t className[] = L"DictatorMDWindowsMainWindow";

    WNDCLASSW windowClass = {};
    windowClass.lpfnWndProc = App::WindowProc;
    windowClass.hInstance = instance;
    windowClass.lpszClassName = className;
    windowClass.hCursor = LoadCursorW(nullptr, IDC_ARROW);

    if (!RegisterClassW(&windowClass)) {
        return false;
    }

    window_ = CreateWindowExW(
        0,
        className,
        L"Dictator-md",
        WS_OVERLAPPEDWINDOW | WS_CLIPCHILDREN,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        940,
        640,
        nullptr,
        nullptr,
        instance,
        this
    );

    if (!window_) {
        return false;
    }

    ShowWindow(window_, showCommand == SW_SHOWDEFAULT ? SW_SHOWNORMAL : showCommand);
    UpdateWindow(window_);
    return true;
}

void App::createChildControls() {
    if (statusLabel_) {
        return;
    }

    constexpr DWORD labelStyle = WS_CHILD | WS_VISIBLE;
    constexpr DWORD buttonStyle = WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON;

    infoLabel_ = CreateWindowExW(
        0, L"STATIC",
        L"Windows preview. Launch first, then choose a hotkey from the window or tray.",
        labelStyle,
        0, 0, 10, 10,
        window_, nullptr, GetModuleHandleW(nullptr), nullptr);

    statusLabel_ = CreateWindowExW(
        0, L"STATIC",
        L"Hotkey: not set yet",
        labelStyle,
        0, 0, 10, 10,
        window_, nullptr, GetModuleHandleW(nullptr), nullptr);

    rightAltButton_ = CreateWindowExW(0, L"BUTTON", L"Use Right Alt hotkey", buttonStyle, 0, 0, 10, 10, window_, reinterpret_cast<HMENU>(IDM_DICTATOR_SET_RIGHT_ALT), GetModuleHandleW(nullptr), nullptr);
    f8Button_ = CreateWindowExW(0, L"BUTTON", L"Use F8 hotkey", buttonStyle, 0, 0, 10, 10, window_, reinterpret_cast<HMENU>(IDM_DICTATOR_SET_F8), GetModuleHandleW(nullptr), nullptr);
    ctrlAltSpaceButton_ = CreateWindowExW(0, L"BUTTON", L"Use Ctrl+Alt+Space hotkey", buttonStyle, 0, 0, 10, 10, window_, reinterpret_cast<HMENU>(IDM_DICTATOR_SET_CTRL_ALT_SPACE), GetModuleHandleW(nullptr), nullptr);
    clearButton_ = CreateWindowExW(0, L"BUTTON", L"Clear hotkey", buttonStyle, 0, 0, 10, 10, window_, reinterpret_cast<HMENU>(IDM_DICTATOR_CLEAR_HOTKEY), GetModuleHandleW(nullptr), nullptr);
    testButton_ = CreateWindowExW(0, L"BUTTON", L"Test insert", buttonStyle, 0, 0, 10, 10, window_, reinterpret_cast<HMENU>(IDM_DICTATOR_TEST_INSERT), GetModuleHandleW(nullptr), nullptr);
    exitButton_ = CreateWindowExW(0, L"BUTTON", L"Exit", buttonStyle, 0, 0, 10, 10, window_, reinterpret_cast<HMENU>(IDM_DICTATOR_EXIT), GetModuleHandleW(nullptr), nullptr);

    refreshStatusText();
}

void App::onHotkey() {
    const auto target = focusTracker_.captureCurrentTarget();
    const auto transcript = pipeline_.runPrototypeDictation();
    if (!transcript.empty()) {
        injector_.insertText(target, transcript);
    }
}

void App::onTrayCommand(UINT command) {
    switch (command) {
    case IDM_DICTATOR_EXIT:
        PostQuitMessage(0);
        break;
    case IDM_DICTATOR_SHOW_STATUS:
        showStatus();
        break;
    case IDM_DICTATOR_SET_RIGHT_ALT:
    case IDM_DICTATOR_SET_F8:
    case IDM_DICTATOR_SET_CTRL_ALT_SPACE:
    case IDM_DICTATOR_CLEAR_HOTKEY:
        configureHotkey(command);
        break;
    case IDM_DICTATOR_TEST_INSERT:
        onHotkey();
        break;
    default:
        break;
    }
}

void App::refreshStatusText() {
    const std::wstring hotkeyLabel = hotkey_.activeHotkeyLabel().empty()
        ? std::wstring(L"Hotkey: not set yet")
        : std::wstring(L"Hotkey: ") + hotkey_.activeHotkeyLabel();
    if (statusLabel_) {
        SetWindowTextW(statusLabel_, hotkeyLabel.c_str());
    }
}

void App::showStatus() {
    refreshStatusText();
    ShowWindow(window_, SW_RESTORE);
    SetForegroundWindow(window_);
}

void App::configureHotkey(UINT command) {
    if (command == IDM_DICTATOR_CLEAR_HOTKEY) {
        hotkey_.unregister(window_);
        refreshStatusText();
        return;
    }

    bool registered = false;
    switch (command) {
    case IDM_DICTATOR_SET_RIGHT_ALT:
        registered = hotkey_.registerRightAlt(window_);
        break;
    case IDM_DICTATOR_SET_F8:
        registered = hotkey_.registerF8(window_);
        break;
    case IDM_DICTATOR_SET_CTRL_ALT_SPACE:
        registered = hotkey_.registerCtrlAltSpace(window_);
        break;
    default:
        return;
    }

    if (registered) {
        refreshStatusText();
    }
}

LRESULT CALLBACK App::WindowProc(HWND window, UINT message, WPARAM wParam, LPARAM lParam) {
    App* app = nullptr;

    if (message == WM_NCCREATE) {
        const auto create = reinterpret_cast<CREATESTRUCTW*>(lParam);
        app = static_cast<App*>(create->lpCreateParams);
        app->window_ = window;
        SetWindowLongPtrW(window, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(app));
    } else {
        app = reinterpret_cast<App*>(GetWindowLongPtrW(window, GWLP_USERDATA));
    }

    if (!app) {
        return DefWindowProcW(window, message, wParam, lParam);
    }

    switch (message) {
    case WM_CREATE:
        app->createChildControls();
        return 0;
    case WM_SIZE:
        app->layoutControls(LOWORD(lParam), HIWORD(lParam));
        return 0;
    case WM_HOTKEY:
        app->onHotkey();
        return 0;
    case WM_COMMAND:
        app->onTrayCommand(LOWORD(wParam));
        return 0;
    case WM_DICTATOR_TRAY:
        if (LOWORD(lParam) == WM_RBUTTONUP || LOWORD(lParam) == WM_LBUTTONUP) {
            app->tray_.showMenu(window);
        }
        return 0;
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    default:
        return DefWindowProcW(window, message, wParam, lParam);
    }
}

void App::layoutControls(int width, int) {
    constexpr int margin = 24;
    constexpr int gap = 12;
    constexpr int buttonHeight = 34;

    const int contentWidth = std::max(0, width - margin * 2);
    const int buttonX = margin;
    const int buttonY = 120;
    const int wideButtonWidth = std::max(240, (contentWidth - gap) / 2);

    if (infoLabel_) {
        SetWindowPos(infoLabel_, nullptr, margin, margin, contentWidth, 30, SWP_NOZORDER);
    }
    if (statusLabel_) {
        SetWindowPos(statusLabel_, nullptr, margin, margin + 38, contentWidth, 28, SWP_NOZORDER);
    }

    if (rightAltButton_) {
        SetWindowPos(rightAltButton_, nullptr, buttonX, buttonY, wideButtonWidth, buttonHeight, SWP_NOZORDER);
    }
    if (f8Button_) {
        SetWindowPos(f8Button_, nullptr, buttonX + wideButtonWidth + gap, buttonY, wideButtonWidth, buttonHeight, SWP_NOZORDER);
    }
    if (ctrlAltSpaceButton_) {
        SetWindowPos(ctrlAltSpaceButton_, nullptr, buttonX, buttonY + buttonHeight + gap, wideButtonWidth, buttonHeight, SWP_NOZORDER);
    }
    if (clearButton_) {
        SetWindowPos(clearButton_, nullptr, buttonX + wideButtonWidth + gap, buttonY + buttonHeight + gap, wideButtonWidth, buttonHeight, SWP_NOZORDER);
    }
    if (testButton_) {
        SetWindowPos(testButton_, nullptr, buttonX, buttonY + (buttonHeight + gap) * 2, wideButtonWidth, buttonHeight, SWP_NOZORDER);
    }
    if (exitButton_) {
        SetWindowPos(exitButton_, nullptr, buttonX + wideButtonWidth + gap, buttonY + (buttonHeight + gap) * 2, wideButtonWidth, buttonHeight, SWP_NOZORDER);
    }
}
