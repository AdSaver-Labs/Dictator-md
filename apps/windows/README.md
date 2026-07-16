# Dictator-md for Windows

This is the native Windows preview scaffold. The macOS app remains the working reference product while Windows catches up.

The Windows shell is intentionally native because these parts need system-level behavior:

- global hotkey
- active window tracking
- microphone capture
- text insertion into the focused app
- tray status/menu

## Current Status

**Windows preview only. This is not a finished Windows dictation app yet.**

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

## Download On Windows

Go to the latest GitHub Release:

https://github.com/AdSaver-Labs/Dictator-md/releases/latest

Download:

```text
Dictator-md-windows-preview.zip
```

Extract the zip and run:

```powershell
.\Dictator-md.exe
```

The Windows preview currently validates the native tray app, hotkey registration, focused-window tracking, and text insertion path. It does **not** yet perform real voice transcription.

## Build On Windows From Source

Requirements:

- Windows 10/11
- Git for Windows
- Visual Studio 2022 with **Desktop development with C++**
- CMake 3.24+

Clone:

```powershell
git clone --recurse-submodules https://github.com/AdSaver-Labs/Dictator-md.git
cd Dictator-md
```

Build:

```powershell
cmake -S apps/windows -B build/windows -G "Visual Studio 17 2022" -A x64
cmake --build build/windows --config Release
```

Run:

```powershell
.\build\windows\Release\Dictator-md.exe
```

## Preview Behavior

Press the registered hotkey to trigger the pipeline. Dictator-md first tries `Right Alt`, then silently falls back to `F8`, then `Ctrl+Alt+Space` if Windows refuses the earlier options. The app still opens even when a preferred hotkey is unavailable; check the tray menu to see the active test hotkey. Until audio and Whisper are wired, it inserts a placeholder sentence into the current focused application:

```text
Dictator-md Windows insertion test.
```

The goal is to validate the Windows-specific control surface first: hotkey, target capture, tray behavior, and insertion.

For a full friend/tester checklist, see [`../../docs/WINDOWS_MANUAL_TESTING.md`](../../docs/WINDOWS_MANUAL_TESTING.md).

## Known Limitations

- The app does not record from the microphone yet.
- The app does not transcribe speech yet.
- The app uses clipboard-based paste insertion and may overwrite clipboard content.
- There is no installer yet; download the release zip and run the executable.

## Useful Feedback

Please report:

- Windows version
- CPU architecture
- Visual Studio version
- CMake version
- build success/failure
- whether tray icon appears
- whether the registered hotkey inserts placeholder text into Notepad
- whether insertion works in browser text fields
- whether insertion works in Cursor/VS Code
- whether clipboard content is overwritten
- any exact errors/screenshots
