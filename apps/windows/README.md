# Dictator-md for Windows

This is the native Windows prototype scaffold. The macOS app remains the working reference product.

The Windows shell is intentionally native because these parts need system-level behavior:

- global hotkey
- active window tracking
- microphone capture
- text insertion into the focused app
- tray status/menu

## Current Status

**Prototype scaffold only. This is not a finished Windows dictation app yet.**

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

## Prototype Behavior

Press `Right Alt` to trigger the pipeline. Until audio and Whisper are wired, it inserts a placeholder sentence into the current focused application:

```text
Dictator-md Windows insertion test.
```

The goal is to validate the Windows-specific control surface first: hotkey, target capture, tray behavior, and insertion.

For a full friend/tester checklist, see [`../../docs/WINDOWS_MANUAL_TESTING.md`](../../docs/WINDOWS_MANUAL_TESTING.md).

## Known Limitations

- The app does not record from the microphone yet.
- The app does not transcribe speech yet.
- The app uses clipboard-based paste insertion and may overwrite clipboard content.
- There is no installer; testers must build from source.
- There is no Windows release artifact yet.

## Useful Feedback

Please report:

- Windows version
- CPU architecture
- Visual Studio version
- CMake version
- build success/failure
- whether tray icon appears
- whether `Right Alt` inserts placeholder text into Notepad
- whether insertion works in browser text fields
- whether insertion works in Cursor/VS Code
- whether clipboard content is overwritten
- any exact errors/screenshots
