# Dictator-md Shared Core

This folder defines the portable product core shared by desktop and mobile apps.

The first shared layer is intentionally data-first:

- dictation event schema
- user profile/settings schema
- language profiles
- correction rules
- memory/storage protocol

Platform apps should depend on these contracts before moving heavier ASR or UI code into shared libraries.

## Principles

- Local-first by default.
- No audio or transcript upload unless the user explicitly chooses an integration later.
- Keep full transcripts user-visible and deletable.
- Keep analytics lightweight and uncapped.
- Keep every platform honest about OS limits.

## Platform Mapping

| Platform | Text Entry Layer | Mobile/Desktop Reality |
| --- | --- | --- |
| macOS | Accessibility + CGEvent insertion | Existing primary product |
| Windows | Win32 window/tray + input simulation | Preview scaffold |
| iOS | Main app + custom keyboard extension | Cannot replace Apple's system dictation key |
| Android | InputMethodService keyboard | Closest mobile match to "any text box" |

