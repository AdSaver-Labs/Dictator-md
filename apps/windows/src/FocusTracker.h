#pragma once

#include <windows.h>

struct FocusTarget {
    HWND foregroundWindow = nullptr;
    HWND focusedControl = nullptr;
};

class FocusTracker {
public:
    FocusTarget captureCurrentTarget() const;
};
