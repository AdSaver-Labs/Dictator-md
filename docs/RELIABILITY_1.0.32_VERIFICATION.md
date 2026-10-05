# Recognition and Insertion Verification - 1.0.32

Implemented and verified by local Mac Codex on 2026-10-05.

## Changes

- Remove nearest-suggestion selection from on-device spelling cleanup. Use the
  system's automatic correction proposal, with a one-edit English guard and a
  Bulgarian guard limited to one adjacent duplicated-letter removal.
- Move all NSSpellChecker access onto the main queue.
- Add three Bulgarian specialist spellings as bounded recognition hints, not
  global replacement rules. No model download or network-based ASR was added.
- Prefer the application's focused window for destination capture, allow a
  bounded wait for initially missing Electron fields, and do not permanently
  cache failed accessibility opt-ins.
- Use clipboard delivery for the actual Hermes desktop bundle. Avoid clicking a
  captured field that already has verified keyboard focus. Preserve point-only
  fallback, cancellation, destination identity and clipboard recovery.

## Evidence

- `make text-smoke`: passed, including uncertain verb preservation, exact
  contextual corrections, unrelated cooking-verb preservation, specialist/slang
  rules, script isolation and duplicated-letter guards.
- `make recognition-smoke`: all 29 policy/persistence/recheck tests passed.
- `make auto-language-smoke`: all 10 language-decision cases passed.
- `make foundations-smoke`, `make insertion-smoke`: passed.
- `make live-insertion-smoke`: all 10 actual external-editor delivery and recovery
  cases passed, including changing fields/windows/apps, long Bulgarian text,
  moved and resized windows, cancellation and newer clipboard content.
- Chrome empty address bar: actual probe readback passed. Selected address-bar
  replacement passed with suggestions visible. Cross-application test passed:
  the original address bar received the probe once; the newer editor was unchanged.
- Hermes empty Message composer: actual probe readback passed. Cross-application
  test passed with the original composer restored and the newer editor unchanged.
  No message was sent. Disposable draft probes were removed.
- Chrome textarea and contenteditable: original-field readback passed after
  switching to the other field; exact selection replacement and the unchanged
  other field were checked through native UI inspection.
- Universal arm64/x86_64 app build passed. Stable local certificate and bundle
  identifier were retained. Installed startup reports AX trusted, keycode 61
  event tap operational and the existing multilingual medium model loaded.
- Five feedback corrections were saved and verified through the installed
  Vocabulary editor. They live only in the user's local corrections.json;
  verb rules require the exact PostgreSQL phrase plus Hermes context. The
  confirmation store is not committed or shipped as other users' vocabulary.

## Recognition Regression

The same six synthetic recordings from 1.0.31, using the existing medium model:

| Fixture | Raw WER | Target spellings |
| --- | --- | --- |
| Bulgarian medicine/brand | 0% | 2/2 |
| English medicine/brand | 0% | 2/2 |
| Bulgarian cities | 0% | 3/3 |
| English technical terms | 0% | 4/4 |
| Longer Bulgarian note | 9.5% | 5/5 |
| Longer English note | 0% | 7/7 |

These results match 1.0.31's fixture scores; the added hints did not regress the
tested recordings. They do not prove perfect natural speech recognition.

## Limits and Privacy

The user's original Chrome failure was intermittent: a baseline empty-bar probe
also passed. Logs showed destination restoration refusing insertion. The patch
removes fragile window capture and redundant clicking, but does not claim every
navigation, popup or rerender is covered. The Hermes failure log had no captured
field or usable anchor; the tested current composer is now delivered correctly.

These integration tests use the production FocusTracker/TextInjector and inspect
actual delivered text, not just event-posting success. They are not a microphone
dictation test with the user's voice. No audio/transcript upload, telemetry,
new model, ASR training, permission reset, signing change, hotkey change,
microphone capture change or node change was made.

Next acceptance: repeat the user's Bulgarian passages, and dictate in Hermes
and Chrome's address bar, including switching apps while decoding. If a field
is destroyed or a page navigates, recovery remains in History/clipboard rather
than guessing a replacement destination.
