# Mobile Execution Plan

## Goal

Bring Dictator-md to iOS and Android without lying about platform limitations.

## Step 1: Shared Core

Status: scaffolded.

- Shared schemas live under `core/schemas`.
- Language profiles live under `core/language`.
- Correction rules live under `core/correction`.
- Memory rules live under `core/memory`.

## Step 2: iOS

Status: scaffolded.

Architecture:

- Main iOS app for settings, history, vocabulary, model management, and recording experiments.
- Keyboard extension for text insertion and quick actions.
- App group storage to share recent dictated text and settings.

Important limitation:

iOS does not let third-party apps replace the system dictation button globally. A custom keyboard can insert text, but microphone access inside keyboard extensions is restricted, so the safe Apple-approved design is main app recording plus keyboard insertion workflows.

## Step 3: Android

Status: scaffolded.

Architecture:

- Main Android app for settings/history/vocabulary.
- `InputMethodService` keyboard for text insertion into any text field where Android allows custom keyboards.
- Later: local ASR service, model downloads, and low-latency streaming insertion.

## Step 4: Mobile ASR

Initial prototypes:

- iOS: `Speech` framework feasibility inside the main app, then local model path research.
- Android: platform speech recognizer for MVP, then local whisper.cpp or whisper-compatible runtime.

Production target:

- Local-first ASR.
- English/Bulgarian profiles.
- Shared correction and personal vocabulary.
- No cloud dependency by default.

