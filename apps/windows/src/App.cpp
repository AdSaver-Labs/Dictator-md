#include "App.h"

#include "WindowsIds.h"

#include <string>

App::App() = default;

int App::run(HINSTANCE instance, int showCommand) {
    (void)showCommand;
    if (!createMessageWindow(instance)) {
        MessageBoxW(nullptr, L"Failed to create Dictator-md message window.", L"Dictator-md", MB_ICONERROR);
        return 1;
    }

    if (!tray_.create(window_, instance, hotkey_.activeHotkeyLabel())) {
        MessageBoxW(nullptr, L"Failed to create Dictator-md tray icon.", L"Dictator-md", MB_ICONERROR);
        return 1;
    }

    MSG message;
    while (GetMessageW(&message, nullptr, 0, 0) > 0) {
        TranslateMessage(&message);
        DispatchMessageW(&message);
    }

    hotkey_.unregister(window_);
    tray_.destroy();
    return static_cast<int>(message.wParam);
}

bool App::createMessageWindow(HINSTANCE instance) {
    constexpr wchar_t className[] = L"DictatorMDWindowsMessageWindow";

    WNDCLASSW windowClass = {};
    windowClass.lpfnWndProc = App::WindowProc;
    windowClass.hInstance = instance;
    windowClass.lpszClassName = className;

    if (!RegisterClassW(&windowClass)) {
        return false;
    }

    window_ = CreateWindowExW(
        0,
        className,
        L"Dictator-md",
        0,
        0,
        0,
        0,
        0,
        HWND_MESSAGE,
        nullptr,
        instance,
        this
    );

    return window_ != nullptr;
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

void App::showStatus() const {
    const std::wstring hotkeyLabel = hotkey_.activeHotkeyLabel().empty()
        ? std::wstring(L"No global hotkey registered yet. Choose a hotkey from this tray menu when you are ready.")
        : std::wstring(L"Active test hotkey: ") + hotkey_.activeHotkeyLabel();
    const std::wstring message = std::wstring(L"Dictator-md Windows preview is running.\n\n") +
        hotkeyLabel +
        L"\n\nThis preview validates launch, tray, hotkey, focus tracking, and placeholder text insertion. Real microphone dictation is still being ported.";
    MessageBoxW(window_, message.c_str(), L"Dictator-md", MB_ICONINFORMATION);
}

void App::configureHotkey(UINT command) {
    if (command == IDM_DICTATOR_CLEAR_HOTKEY) {
        hotkey_.unregister(window_);
        MessageBoxW(window_, L"Global hotkey cleared. The app is still running in the tray.", L"Dictator-md", MB_ICONINFORMATION);
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
        const std::wstring message = std::wstring(L"Registered hotkey: ") + hotkey_.activeHotkeyLabel();
        MessageBoxW(window_, message.c_str(), L"Dictator-md", MB_ICONINFORMATION);
    } else {
        MessageBoxW(window_, L"Windows refused that hotkey. Pick another option from the tray menu.", L"Dictator-md", MB_ICONWARNING);
    }
}

LRESULT CALLBACK App::WindowProc(HWND window, UINT message, WPARAM wParam, LPARAM lParam) {
    App* app = nullptr;

    if (message == WM_NCCREATE) {
        const auto create = reinterpret_cast<CREATESTRUCTW*>(lParam);
        app = static_cast<App*>(create->lpCreateParams);
        SetWindowLongPtrW(window, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(app));
    } else {
        app = reinterpret_cast<App*>(GetWindowLongPtrW(window, GWLP_USERDATA));
    }

    if (!app) {
        return DefWindowProcW(window, message, wParam, lParam);
    }

    switch (message) {
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
