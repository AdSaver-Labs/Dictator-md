# Download Dictator-md

This page is for people who just want to download and run the app.

## macOS

The macOS app is the current main product.

1. Open the latest release:
   https://github.com/AdSaver-Labs/Dictator-md/releases/latest
2. Download `Dictator-md.dmg`.
3. Open the DMG.
4. Drag `Dictator-md.app` into Applications.
5. Open Dictator-md from Applications.

macOS may block the first launch because the app is not notarized yet.

If that happens:

1. Try opening Dictator-md once.
2. Open System Settings.
3. Go to Privacy & Security.
4. Scroll down and click Open Anyway for Dictator-md.
5. Open Dictator-md again.

After launch, grant:

- Microphone access, for recording your voice.
- Accessibility access, for global hotkey and text insertion.

## Windows

The Windows app is currently a preview, not the full dictation product yet.

1. Open the latest release:
   https://github.com/AdSaver-Labs/Dictator-md/releases/latest
2. Download `Dictator-md-windows-preview.zip`.
3. Extract the zip.
4. Run `Dictator-md.exe`.

Current Windows preview behavior:

- Tray app launches.
- Right Alt is tried first, with F8 and Ctrl+Alt+Space as automatic fallbacks if Windows refuses it.
- Focused-window tracking is wired.
- Text insertion path is wired.
- It inserts a placeholder test sentence.

Not implemented yet on Windows:

- Microphone capture.
- Local Whisper transcription.
- Settings/history/vocabulary UI.
- Installer.

## Build From Source

Use this path only if you are a developer.

```bash
git clone --recurse-submodules https://github.com/AdSaver-Labs/Dictator-md.git
cd Dictator-md
```

For macOS:

```bash
./scripts/build-whisper.sh
make app
make install-local
```

For Windows, see:

- `apps/windows/README.md`
- `docs/WINDOWS_MANUAL_TESTING.md`

## Which File Should I Download?

| Platform | Download |
| --- | --- |
| macOS | `Dictator-md.dmg` |
| Windows | `Dictator-md-windows-preview.zip` |

If you are not sure which file to download, use the table above.
