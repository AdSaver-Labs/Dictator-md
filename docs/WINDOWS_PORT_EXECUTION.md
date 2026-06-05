# Dictator-md Windows Port Execution

Status: native Windows prototype scaffold started. The macOS app is still the working reference product.

The Windows version should not be a rushed rewrite. It should share product behavior with macOS while using native Windows APIs for the parts that must feel system-level.

## Target MVP

1. Tray application named Dictator-md.
2. Global push-to-talk hotkey.
3. Toggle mode for long dictation.
4. Local microphone capture.
5. Local Whisper transcription through whisper.cpp.
6. Active-window text insertion.
7. Clipboard paste fallback.
8. History, vocabulary, and language settings.
9. English/Bulgarian language profiles.
10. No cloud requirement.

## Native Windows Responsibilities

The Windows shell owns:
- System tray UI.
- Global hotkey registration.
- Microphone device selection.
- Active foreground window tracking.
- Text insertion into the focused control.
- Installer and auto-start option.

Likely APIs:
- `RegisterHotKey` for global hotkeys.
- WASAPI for microphone capture.
- `GetForegroundWindow` and UI Automation for target detection.
- Clipboard plus `SendInput` for reliable paste.
- Optional UI Automation `ValuePattern`/`TextPattern` for direct insertion where supported.

## Shared Core Candidates

Move these concepts out of macOS-only Swift over time:
- Text correction rules.
- Custom term protection.
- Repetition collapse.
- Language guardrails.
- Learned vocabulary ranking.
- History schema.
- Model metadata and download catalog.
- Prosody analysis logic.

The first shared-core extraction can be language-neutral data and tests, not a full rewrite:
- `schemas/history.schema.json`
- `schemas/settings.schema.json`
- `docs/core-behavior.md`
- cross-platform correction test fixtures

## First Implementation Path

Phase 1: Desktop contract
- Document the exact dictation pipeline from macOS.
- Add portable JSON schemas for history/settings/vocabulary.
- Add correction fixtures for English and Bulgarian.

Phase 2: Windows prototype
- Build a minimal tray app.
- Capture audio.
- Run local whisper.cpp inference.
- Paste into Notepad and browser fields.

Phase 3: Product parity
- Add settings window.
- Add model manager.
- Add history/vocabulary.
- Add floating status node or tray mini-panel.

Phase 4: Packaging
- Build installer.
- Add Windows code signing plan.
- Add GitHub Actions build.
- Add release artifacts.

## Non-Negotiable Reliability Rules

- Never ship a Windows build that only copies text without attempting insertion.
- Always preserve the target window captured at recording start.
- Always keep a clipboard paste fallback.
- Do not block dictation on UI polish.
- Do not start mobile work before the shared history/vocabulary schema is stable.

## Current Gap

Windows now has a native CMake/Win32 tray scaffold under `apps/windows`.

Implemented in the scaffold:
- Hidden message window.
- Tray icon and menu.
- Prototype Right Alt hotkey registration.
- Focus target capture at dictation start.
- Clipboard plus `Ctrl+V` text insertion path.
- GitHub Actions Windows build job.

Not implemented yet:
- WASAPI microphone capture.
- whisper.cpp inference binding.
- Real settings/history UI.
- Installer, signing, and auto-start.

The immediate next engineering step is to replace the prototype transcription string with WASAPI capture and local whisper.cpp inference, then test insertion in Notepad, browsers, chat boxes, and terminals.
