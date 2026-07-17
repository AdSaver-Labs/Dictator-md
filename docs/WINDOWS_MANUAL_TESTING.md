# Windows Manual Testing Guide

This guide is for technical testers who want to help validate the Windows port of Dictator-md.

## Important Status

The Windows build is currently a **prototype**, not the finished dictation app.

What works today:

- Native Win32 app launches.
- Tray icon/menu is created.
- Global hotkey registration is wired, but hotkeys are selected manually from the tray after launch.
- The app can detect the foreground window.
- The app can paste text into the focused application using clipboard + `SendInput`.
- Pressing the prototype hotkey inserts a placeholder sentence.

What does **not** work yet:

- No microphone recording yet.
- No Whisper transcription yet.
- No model download/selection flow yet.
- No settings UI yet.
- No installer yet.
- No real dictation output yet.

Please test it as a Windows control-surface prototype, not as a finished speech-to-text app.

## Requirements

Install these first:

1. **Git for Windows**
   - https://git-scm.com/download/win
2. **Visual Studio 2022 Community**
   - https://visualstudio.microsoft.com/vs/community/
   - During installation, select **Desktop development with C++**.
3. **CMake**
   - https://cmake.org/download/
   - During installation, allow CMake to be added to PATH.

## Get the Code

Open **PowerShell** and run:

```powershell
git clone --recurse-submodules https://github.com/AdSaver-Labs/Dictator-md.git
cd Dictator-md
```

If the submodules did not download correctly, run:

```powershell
git submodule update --init --recursive
```

## Build the Windows Prototype

From the repository root, use one of these build paths.

### Option A — Visual Studio generator

```powershell
cmake -S apps/windows -B build/windows -G "Visual Studio 17 2022" -A x64
cmake --build build/windows --config Release
```

Expected output:

```text
build\windows\Release\Dictator-md.exe
```

### Option B — MSVC + Ninja

If the Visual Studio generator is not found, open a **Developer PowerShell for VS 2022** window and run:

```powershell
cmake -S apps/windows -B build/windows -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build/windows
```

Expected output:

```text
build\windows\Dictator-md.exe
```

## Run It

```powershell
.\build\windows\Release\Dictator-md.exe
```

Look for the Dictator-md tray icon.

## What to Test

### 1. App launch

Pass if:

- The app starts without crashing.
- A tray icon appears.
- The app can be exited from the tray/menu if an exit option is present.

Fail if:

- Windows Defender blocks it.
- The app crashes on launch.
- No tray icon appears.

### 2. Placeholder insertion

Open Notepad, click into the empty document, then use the visible Dictator-md window or tray menu to choose one of the hotkey options: **Use Right Alt hotkey**, **Use F8 hotkey**, or **Use Ctrl+Alt+Space hotkey**. Press the chosen hotkey.

Pass if placeholder text appears:

```text
Dictator-md Windows insertion test.
```

Fail if:

- Nothing happens.
- The text appears in the wrong app.
- The hotkey triggers unrelated Windows behavior.
- The app crashes.

### 3. Browser text field insertion

Open a browser, click into a normal text field, and press the registered hotkey.

Pass if the placeholder text appears in the field.

Fail if it inserts somewhere else or does nothing.

### 4. Cursor / code editor insertion

Open Cursor, VS Code, or another editor. Click into a text file and press the registered hotkey.

Pass if the placeholder text appears at the cursor.

Fail if:

- It pastes into a different window.
- It breaks editor focus.
- It triggers a conflicting shortcut.

### 5. Clipboard behavior

Because the prototype uses the clipboard to paste text, test whether your previous clipboard content is overwritten.

Steps:

1. Copy some text manually, e.g. `clipboard-test`.
2. Trigger Dictator-md insertion.
3. Paste again somewhere else.

Report whether the old clipboard content was preserved or replaced.

## What Feedback to Send

Please send:

- Windows version: Windows 10/11, build if known.
- CPU: Intel/AMD/ARM.
- Visual Studio version.
- CMake version: `cmake --version`.
- Whether build succeeded.
- Whether app launched.
- Whether tray icon appeared.
- Whether the registered hotkey inserted placeholder text in:
  - Notepad
  - browser field
  - Cursor / VS Code
- Whether clipboard was overwritten.
- Any screenshots or exact error messages.

## Current Development Priorities

Before Windows can become a real dictation app, the next engineering work is:

1. WASAPI microphone recording.
2. Save captured audio to a test WAV/PCM file.
3. whisper.cpp integration on Windows.
4. Model path/download settings.
5. Real transcript insertion instead of placeholder text.
6. Safer text injection with clipboard restore or UI Automation where possible.
7. Installer/release packaging.
