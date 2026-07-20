# Dictator-md for iOS

This is the iOS scaffold for Dictator-md.

## Architecture

- `DictatorMDiOS`: main app for onboarding, settings, history, vocabulary, and recording experiments.
- `DictatorMDKeyboard`: keyboard extension for inserting Dictator-md text into text fields.
- Shared storage should use an App Group:
  - `group.com.dictatormd.shared`

## Platform Reality

iOS does not allow Dictator-md to replace Apple's built-in dictation button globally.

The approved path is:

1. User enables the Dictator-md custom keyboard.
2. Main app handles settings/history/vocabulary and recording experiments.
3. Keyboard extension inserts recent dictation text or typed commands into the current text field.

Microphone capture inside keyboard extensions is restricted. Do not design this as a direct clone of the macOS global overlay.

## Next Build Tasks

1. Generate an Xcode project with the iOS app and keyboard extension targets.
2. Configure App Group entitlements.
3. Add a first-run setup guide for enabling the keyboard.
4. Prototype main-app recording with Apple's Speech framework.
5. Add shared storage between app and keyboard.

