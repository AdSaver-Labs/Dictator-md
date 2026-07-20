# Dictator-md for Android

This is the Android scaffold for Dictator-md.

## Architecture

- Main app for setup, settings, history, vocabulary, and model management.
- Custom keyboard/IME using `InputMethodService`.
- The IME inserts text through Android's `InputConnection`, which is the correct mobile equivalent of "works in any text box."

## Current Scaffold

- Kotlin Android project layout.
- Main activity.
- Dictator-md keyboard service.
- Shared local store for recent dictation text and profile settings.
- Placeholder insertion path.

## Next Build Tasks

1. Add Gradle wrapper pinned to the repo.
2. Add first real UI with Compose or native views.
3. Add keyboard enable/setup onboarding.
4. Wire platform speech recognizer for MVP.
5. Add local ASR runtime after performance testing.

