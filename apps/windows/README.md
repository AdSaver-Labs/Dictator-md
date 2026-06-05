# Dictator-md for Windows

This is the native Windows prototype scaffold. The macOS app remains the working reference product.

The Windows shell is intentionally native because these parts need system-level behavior:

- global hotkey
- active window tracking
- microphone capture
- text insertion into the focused app
- tray status/menu

## Current Status

Prototype scaffold only.

Implemented:
- hidden Win32 message window
- tray icon
- global hotkey registration
- foreground-window capture
- clipboard + `SendInput` paste insertion
- dictation pipeline placeholder

Not implemented yet:
- WASAPI recording
- whisper.cpp inference
- model manager
- settings UI
- history/vocabulary UI
- installer

## Build On Windows

```powershell
cmake -S apps/windows -B build/windows -G "Visual Studio 17 2022" -A x64
cmake --build build/windows --config Release
```

Run:

```powershell
.\build\windows\Release\Dictator-md.exe
```

## Prototype Behavior

Press `Right Alt` to trigger the pipeline. Until audio and Whisper are wired, it inserts a placeholder sentence into the current focused application.

The goal is to validate the Windows-specific control surface first: hotkey, target capture, and insertion.
