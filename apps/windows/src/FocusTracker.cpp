#include "FocusTracker.h"

FocusTarget FocusTracker::captureCurrentTarget() const {
    FocusTarget target;
    target.foregroundWindow = GetForegroundWindow();
    target.focusedControl = target.foregroundWindow;

    if (!target.foregroundWindow) {
        return target;
    }

    const DWORD foregroundThread = GetWindowThreadProcessId(target.foregroundWindow, nullptr);
    GUITHREADINFO info = {};
    info.cbSize = sizeof(info);
    if (GetGUIThreadInfo(foregroundThread, &info) && info.hwndFocus) {
        target.focusedControl = info.hwndFocus;
    }

    return target;
}
