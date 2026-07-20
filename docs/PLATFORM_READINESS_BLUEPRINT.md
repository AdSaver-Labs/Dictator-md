# Dictator-md Platform Readiness Blueprint

Updated: 2026-07-20

## Purpose

This is the execution order for turning Dictator-md from a working macOS product plus Windows/mobile scaffolds into a reliable, local-first multi-platform application. It preserves the current macOS dictation core and does not prescribe a visual redesign.

## Audit Result

| Area | Current reality | Release readiness |
| --- | --- | --- |
| macOS dictation | Local Whisper.cpp, microphone capture, global hotkey, captured-target insertion, history, vocabulary, updater | Working product; needs reliability/performance hardening |
| Windows | Native app/tray/manual hotkey/focus capture/clipboard paste shell | Preview only; no audio capture or ASR |
| iOS | App, app-group storage, custom keyboard shell | Scaffold only; recording and transcription are not implemented |
| Android | App and `InputMethodService` shell | Scaffold only; no microphone capture or ASR |
| Shared core | JSON contracts and duplicated platform data models | Contract layer only; no shared executable behavior |
| Release engineering | macOS DMG + Windows ZIP released; iOS/Android not released | Desktop release path is incomplete for public distribution |

## Checks Run In This Audit

- macOS universal app build: passed.
- macOS node/history/monthly UI checks: passed.
- Compact dashboard sidebar check: failed before this pass because the sidebar could be clipped at 760 x 540; fixed by forcing a scroll surface below the sidebar's required height.
- Mobile scaffold and contract validation: passed before the new compile gates.
- Windows native build and launch: confirmed from the latest successful GitHub Actions run. It verifies launch only, not actual dictation.
- iOS local simulator build: blocked on this Mac because only Xcode Command Line Tools are installed, not full Xcode. CI now builds the generated iOS app and keyboard extension on a full macOS runner.
- Android local build: blocked because no Android SDK/Gradle installation is present. CI now downloads a pinned Gradle distribution and builds the app/IME on a runner with the Android SDK.

## Non-Negotiable Product Rules

1. Do not change the macOS dictation pipeline without a regression test for hotkey, capture, transcription, target restore, insertion fallback, and copied-transcript recovery.
2. No platform may claim "works anywhere" where its operating system denies that capability. iOS cannot replace Apple dictation globally and third-party keyboard extensions cannot access the microphone.
3. Audio and transcripts remain local by default. Cloud or agent features require an explicit, separately visible opt-in.
4. A failed insertion must preserve the transcript, show a recoverable error, and offer copy/retry instead of silently dropping text.
5. Model downloads, updates, and privacy disclosures must use the same product truth across every platform.

## Execution Roadmap

### P0 - Guardrails and Proof (implemented in this pass)

- [x] Fix the compact-height sidebar clipping path without changing the dashboard design.
- [x] Stop console logging raw dictated text from the correction stage.
- [x] Add platform contract verification.
- [x] Add iOS compilation to CI using XcodeGen and an unsigned simulator build.
- [x] Add Android debug compilation to CI with a pinned Gradle version.
- [ ] Add macOS unit-test execution to CI through the generated Xcode project.
- [ ] Add Windows unit tests for focus capture, clipboard preservation, and hotkey fallback.

### P1 - macOS Reliability and Speed

- [ ] Replace the current JSON-only memory store with SQLite plus daily aggregates, keeping transcript history user-deletable and analytics uncapped.
- [ ] Add an insertion transaction: capture target + selected range at start, restore once, try AX direct insertion, then clipboard paste, then retry/copy with an explicit error.
- [ ] Preserve and restore the user clipboard after paste, with change-count protection so new clipboard content is never overwritten.
- [ ] Add an insertion diagnostics panel that records target/app/strategy/result but never raw transcript text unless the user explicitly exports diagnostics.
- [ ] Add audio-level calibration, selectable input gain/noise handling, and a quiet-speech test to improve whisper dictation without fabricating audio.
- [ ] Benchmark latency by model, clip duration, language, and hardware class; surface only useful local metrics to the user.
- [ ] Add regression fixtures for duplicate suppression, language guards, punctuation, intonation formatting, custom-term preservation, and English/Bulgarian cleanup.

### P2 - Bulgarian Quality

- [ ] Separate English-only and multilingual model catalogs. English mode must use English-only models; Bulgarian and Auto must use multilingual models only.
- [ ] Add curated Bulgarian dictation fixtures, including colloquial speech, borrowed technical terms, names, punctuation, and common confusions.
- [ ] Evaluate multilingual `small`, `medium`, and `large-v3-turbo` compatible quantizations on held-out Bulgarian clips before selecting defaults.
- [ ] Add user correction pairs: a user-approved correction teaches a local replacement rule, rather than treating every recognized token as trustworthy vocabulary.
- [ ] Add per-language confidence/script guards and an explicit "keep original" escape hatch when cleanup is uncertain.

### P3 - Windows Product Parity

- [ ] Implement WASAPI microphone capture with input-device selection and a visible recording level.
- [ ] Build/link whisper.cpp on Windows, including a model downloader, checksum verification, and multilingual model selection.
- [ ] Replace the placeholder pipeline with real local transcription and shared correction fixtures.
- [ ] Add UI Automation direct insertion where supported; retain clipboard-plus-`SendInput` fallback with clipboard restoration.
- [ ] Add settings, history, vocabulary, language choice, toggle mode, diagnostic log, and recovery UI.
- [ ] Add an MSIX or signed installer, first-run permissions guidance, automatic update path, and Windows signing before broad release.
- [ ] Test real transcription/insertion in Notepad, Chromium, Firefox, VS Code, terminal, Slack/Teams, Telegram/Viber, and password/secure-field failure cases.

### P4 - Android Product

- [ ] Build a real settings/history/vocabulary app around the custom IME.
- [ ] Record only after user action with `RECORD_AUDIO`; use a foreground microphone service and its required visible notification when recording continues outside the app.
- [ ] Run local ASR behind a Kotlin/native boundary, package models as user-managed downloads, and measure memory/thermal behavior on modest devices.
- [ ] Make the IME insert transcripts through `InputConnection`, handle editor restarts, rich editors, and unavailable input connections, and retain a copy/retry fallback.
- [ ] Add offline correction/vocabulary, Android backup/export/delete controls, battery-aware limits, Play Data Safety declarations, and Play internal testing.
- [ ] Test on physical ARM64 and emulator devices across current Android versions and major chat/browser/editor fields.

### P5 - iOS Product

- [ ] Keep recording in the containing app: third-party keyboards cannot use the microphone. The keyboard inserts an already-created transcript only.
- [ ] Implement main-app audio capture, local model lifecycle, transcription, history, language settings, corrections, and a handoff to the keyboard extension via App Group storage.
- [ ] Add a clear Quick Dictate flow: open app/shortcut, record, transcribe locally, then insert from the Dictator-md keyboard in compatible fields.
- [ ] Implement a complete keyboard, including typing keys, next-keyboard control, offline operation without Full Access, and clear supported/unsupported-field messaging.
- [ ] Add iOS privacy manifest, App Store privacy nutrition labels, deletion/export, microphone recording indicator, TestFlight, and real-device testing.
- [ ] Do not promise replacement of Apple's dictation key: Apple does not permit it and custom keyboards cannot access the microphone.

### P6 - Shared Core and Operations

- [ ] Promote the current JSON contracts into versioned migrations and compatibility tests across macOS, Windows, iOS, and Android.
- [ ] Extract deterministic correction, duplicate collapse, language/script guards, statistics, and vocabulary ranking into a portable core with identical test fixtures on each platform.
- [ ] Define a model manifest with SHA256, language capability, quantization, RAM estimate, storage size, and minimum device requirements.
- [ ] Add crash-safe persistence, migration backups, data export/import, per-item delete, clear-all, and restore verification.
- [ ] Add dependency/SBOM/license checks, release provenance, signed artifacts, version-channel policy, rollback instructions, and a public issue template for insertion failures.
- [ ] Add accessibility, keyboard navigation, Dynamic Type/mobile scaling, reduced motion, and localization checks to the test matrix.

## Platform Reality

Android is the closest mobile platform to the desktop promise: a custom IME can be selected for most normal text fields. iOS can offer a good main-app plus keyboard workflow, but cannot globally replace Apple's dictation button; Apple custom keyboard extensions cannot access the microphone. These are OS rules, not missing engineering effort. Apple also requires a functional keyboard without Full Access and a clear recording indication/privacy policy. Android requires correct microphone permissions and foreground-service declarations for microphone access outside a visible activity.

Sources: [Apple custom keyboard documentation](https://developer.apple.com/documentation/uikit/creating-a-custom-keyboard), [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), [Android foreground microphone services](https://developer.android.com/about/versions/11/privacy/foreground-services), [Android InputMethodService](https://developer.android.com/reference/android/inputmethodservice/InputMethodService).

## Definition of Ready for a Public Platform Release

A platform is ready only when all of these are true:

- real local microphone capture and ASR are implemented;
- normal text-field insertion is proven on physical devices plus representative apps;
- permissions, errors, clipboard/transcript recovery, data deletion, and model management work;
- automated builds/tests pass for that platform;
- install/update/signing/privacy/store requirements are complete;
- the platform's limitations are clearly disclosed in-app and in download copy.
