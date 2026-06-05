# Dictator-md International Execution Plan

Dictator-md should become a local-first AI writing layer, not only a dictation clone. The product promise is:

> Free local dictation, correction, and personal vocabulary for every text box your platform allows.

## Product Pillars

1. Dictate anywhere
   - macOS: global hotkey, floating node, Accessibility text injection.
   - Windows: global hotkey, active-field insertion, tray app.
   - Android: custom keyboard/IME with local dictation button.
   - iOS: main app plus keyboard extension within Apple's restrictions.

2. Correct and polish locally
   - Grammar cleanup.
   - Spoken punctuation.
   - Intonation-aware formatting.
   - Tone/style suggestions.
   - Protected custom terms.

3. Learn the user
   - Local vocabulary memory.
   - Repeated-term learning.
   - Per-language profiles.
   - Per-app formatting profiles.
   - Optional export/import, no cloud dependency.

4. International by design
   - English and Bulgarian as launch-quality languages.
   - Language packs after that.
   - Clear UI strings ready for localization.
   - Regional privacy/store pages.

## Platform Strategy

### macOS

Status: primary working product.

Near-term goals:
- Keep the bundle identifier stable: `com.dictatormd.DictatorMD`.
- Keep signing stable: `Dictator-md Stable Local`.
- Build signed/notarized DMG releases.
- Add automatic update support.
- Add crash-safe debug logging and export diagnostics.

Distribution:
- GitHub Releases first.
- Website download second.
- Mac App Store only after sandbox limitations are reviewed.

### Windows

Goal: match the macOS desktop promise.

Required native shell:
- Global hotkey.
- Microphone capture.
- Local ASR core.
- Active window tracking.
- Text insertion by clipboard fallback plus native input simulation.
- Tray node/menu.
- Windows installer.

Distribution:
- GitHub Releases.
- Website download.
- Microsoft Store later.

### Android

Goal: strongest mobile implementation.

Architecture:
- Android app plus custom keyboard using `InputMethodService`.
- Dictation button inside keyboard.
- Insert recognized text with the current input connection.
- Local model management.
- User dictionary and correction settings.

Distribution:
- Google Play.
- Optional APK releases from GitHub for advanced users.

### iOS

Goal: best possible Apple-approved mobile version.

Reality:
- We cannot replace Apple's built-in dictation key.
- A custom keyboard can insert text, but microphone access is restricted in keyboard extensions.

Architecture:
- Main app for recording, settings, history, vocabulary, models, and correction.
- Keyboard extension for insertion and quick actions.
- Shared app group storage for recent dictations and vocabulary.
- Clipboard/extension workflow if direct microphone capture is blocked.

Distribution:
- TestFlight first.
- App Store after review-risk pass.

## Monetization

Desktop should remain free and open source.

Mobile options:
- Free app with optional Pro.
- Pro price target: $0.99/month or $9.99/year.

Free tier:
- Local dictation.
- Basic history.
- Basic vocabulary.
- English/Bulgarian language profiles.

Pro tier:
- Advanced correction.
- Style rewrite profiles.
- Export/import.
- More language packs.
- Power-user keyboard modes.
- Advanced personal dictionary controls.

## Technical Architecture

Target repository structure:

```text
core/
  asr/
  correction/
  prosody/
  language/
  memory/
  models/
apps/
  macos/
  windows/
  android/
  ios/
docs/
  protocols/
  release/
  store/
```

The current Swift macOS app can remain the first product, but the shared logic should gradually move toward a core that can be reused by Windows and mobile.

## Intonation-Aware Formatting

Current implementation:
- Toggle in Control: `Intonation-aware punctuation`.
- Off by default.
- Handles spoken punctuation commands.
- Adds question marks to question-like English/Bulgarian phrases.
- Adds exclamation marks to clear emphasis phrases.
- Analyzes raw audio for speech ratio, pauses, ending pitch rise, and emphasized endings.
- Uses pitch/emphasis signals conservatively on short utterances only.

Next implementation:
- Align pause lengths with transcript segments once word/segment timestamps are available.
- Use silence duration for comma, sentence break, and paragraph break decisions.
- Add per-user calibration so quiet speakers and whispering are handled better.
- Keep this as a formatter, not an emotional classifier.

Quality gate:
- Must never corrupt long prompts.
- Must be instantly disableable.
- Must store before/after examples in local diagnostics.

## Correction And Suggestions

Phase 1:
- Existing rule-based grammar/punctuation cleanup.
- Custom term protection.
- Spoken punctuation.
- Repetition collapse.

Phase 2:
- Inline suggestion history.
- "Accept correction" and "undo last correction".
- Per-app correction profiles.

Phase 3:
- Optional local model integration for rewrite suggestions.
- Local-only by default.
- Optional plugin mode for user-owned local servers.

## Self-Learning

Current:
- Local history.
- Learned terms.
- Prompt biasing.

Next:
- Confidence-style term scoring.
- Per-language learned terms.
- Per-app learned terms.
- Manual approve/promote queue.
- Duplicate phrase detection metrics.

Protocol:
- Never upload user text/audio by default.
- Keep learned data inspectable and deletable.
- Keep all self-learning explainable in the UI.

## Launch Plan

1. Private alpha
   - Stabilize macOS.
   - Add DMG release.
   - Add issue templates and crash logs.

2. Public GitHub beta
   - Website.
   - Installation guide.
   - Demo videos.
   - Privacy page.
   - Roadmap.

3. Desktop expansion
   - Windows prototype.
   - Shared core extraction.

4. Mobile expansion
   - Android keyboard MVP.
   - iOS feasibility prototype.

5. Store launch
   - Google Play internal testing.
   - TestFlight.
   - Pricing experiment.
   - Public free desktop downloads.

## Marketing Position

Primary:
- "Free local AI dictation for every text box."

Secondary:
- "A private Wispr Flow alternative."
- "Offline voice typing with personal vocabulary."
- "Built for developers, writers, and multilingual users."

Launch channels:
- GitHub.
- Product Hunt.
- Hacker News Show HN.
- Reddit macOS, Windows, Android, self-hosted, open-source, AI communities.
- YouTube/TikTok demos.
- SEO pages for Wispr Flow alternatives and offline dictation.

## Release Quality Checklist

Before every public release:
- Dictation works in browser text boxes.
- Dictation works in Notion.
- Dictation works in Terminal.
- English forced mode never outputs Cyrillic.
- Bulgarian mode outputs Cyrillic.
- Accessibility status is correct after rebuild.
- Floating node does not block screen edges.
- History does not visually overlap.
- Dashboard week is current calendar week.
- App name is `Dictator-md` everywhere user-facing.
- Signed build keeps the same identity.
