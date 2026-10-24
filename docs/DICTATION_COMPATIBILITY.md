# Dictation Compatibility Checkpoint

## 1.0.36 Cold-Start Paste Crash

Crash reports from 1.0.33, 1.0.34 and 1.0.35 identified Carbon input-source
registry calls on a background delivery thread. Recognition had finished; the
crash occurred while resolving Command-V. A fresh-process detached lookup
reproduced a registry initialization crash, while a main-thread-primed process
passed. Warm editor tests alone were insufficient coverage.

All current input-source lookup, property access, key translation and source
release now occur on the main queue. Delivery itself stays on the background
serial queue. Synchronous UI-thread delivery is rejected without touching the
clipboard, avoiding a main/typing-queue deadlock. Do not remove either boundary.
Production recording, model, recognition, hotkey, signing and permission behavior
are unchanged. The engine's additional target parameter is test-only.

Local verification on 2026-10-24:
- 7,200 detached/concurrent keyboard lookups across cold and primed processes,
  plus main-thread lookup and invalid-caller/deadlock guards, passed.
- All 19 external-editor delivery checks and five keyboard layouts passed.
- Four full engine-to-editor checks passed: explicit English/Bulgarian and Auto
  for both, each using the existing medium model, isolated History, original
  target restoration and confirmed exact clipboard replacement.
- Correction, recognition/persistence, language sampling, clipboard ownership,
  cancellation and language-review recovery checks passed. Universal app built.

`make keyboard-threading-smoke` is now a CI gate and must run in fresh processes.
`make language-review-engine-build` also builds the opt-in live pipeline test:
run its executable with the existing model path, synthetic fixture directory and
`--pipeline`. This temporarily switches disposable windows; coordinate an idle
desktop first. Its AppKit run loop must remain active for focus notifications.
These checks do not replace physical microphone/hotkey tests or verification of
every third-party editor, and do not establish perfect mixed-language accuracy.

## 1.0.34 Delivery Hardening

- Capture a bounded readable draft in RAM with its original UTF-16 selection.
  Refuse insertion if the draft changed or the selection cannot be restored.
  Secure text fields are excluded; surrounding draft text is never persisted or
  logged. The recording/preview operation releases its snapshot on completion.
- Confirm the expected complete edit, not a coincidental matching substring.
  Poll delayed AX responses for at most 800 ms. A timed-out/acknowledged write
  never falls through to a second insertion that could duplicate the text.
- Check whether AX selected-text writes are supported before using that path.
  Clipboard-compatible editors retain their existing routing. Clipboard failure
  no longer triggers speculative Unicode typing into a potentially changed field.
- Clipboard restoration uses the ownership counter captured at our write, not
  a later counter that might belong to a new user copy during paste consumption.
- New History items record delivery outcome, strategy, bounded reason and timing
  alongside the existing destination bundle. Expanded rows show the explanation;
  a Copy button provides recovery. Old history remains readable without inventing
  delivery results. No telemetry, audio upload or new model is introduced.

Local verification: expanded 19-check suite passed with disposable external
editors, including changed drafts, rejected selections, delayed AX edits,
clipboard-only edits, newer copies during paste, closed windows and secure fields.
Seven exact-readback contracts also run without GUI permission in CI. The
production History row was checked at 640 and 1120 px widths; Copy retained the
Bulgarian text. Hermes received the unsent probe once after switching to another
app and the other editor stayed unchanged. Hermes still reports placeholder text
as AXValue, so this tested delivery was correctly left **unverified** rather than
claiming an exact expected-edit match. The probe was removed without submission.
Chrome native automation timed out; the test refused a non-test window. Chrome
and Codex are not newly verified in this pass. Earlier compatibility results
below are historical evidence, not a claim that every current editor state works.

The installed 1.0.34 build retained the stable certificate and trusted Accessibility
state, registered Right Option (61), and loaded the existing multilingual medium
model. Monthly activity, History, node footprint, dashboard resizing and
single-instance checks passed after installation. Text correction, 31 recognition/
persistence checks, 19 language decisions and clipboard/cancellation foundations
also passed. The microphone and ASR implementations were not changed in this slice.

### Non-Negotiable Delivery Rules

1. The recording owns its frozen app/window/field/selection; never substitute the
   current foreground text box after processing starts.
2. A new draft, unavailable selection, secure field or lost owner must result in
   recovery, not a guessed destructive edit.
3. A sent event or successful AX setter is not proof of delivery. Never blindly
   retry an acknowledged, timed-out or unverified write.
4. Preserve History before dispatch. Preserve newer clipboard copies and keep
   an explicit Copy action available; do not promise the clipboard still holds
   the transcript after the user copies something else.
5. Keep AX handles/draft snapshots ephemeral. Persist only delivery metadata
   beside the user's existing local transcript, never surrounding editor text.
6. Run live external-editor tests before installation. Do not rotate signing,
   reset permissions or replace the installed app to make a test appear to pass.
7. Carbon input-source APIs are main-queue-only. Keep synchronous delivery off
   the UI thread and test cold starts, not just warmed-up clipboard paths.

Version 1.0.30 repairs regressions introduced by 1.0.29's target verification.
The recorded destination no longer expires during processing or depends on the
global latest click. The original window is restored even when another window
of the same app is frontmost. Electron's documented `AXManualAccessibility`
opt-in enables field capture where supported; this does not bypass macOS consent.

Failed or unconfirmed delivery retains a transcript on the clipboard unless a
newer user copy would be overwritten. History and explicit Copy remain available.
Only confirmed clipboard delivery restores the previous clipboard when that
setting is enabled. Cancellation suppresses recovery writes as well as insertion.

Version 1.0.32 prefers the application's focused window when capturing a
destination, retries an initially missing Electron field for up to 300 ms,
and retries unsuccessful AXManualAccessibility opt-ins on subsequent captures.
Hermes (`com.nousresearch.hermes`) uses clipboard paste so its editor receives
normal input events. A verified captured field must not be clicked again merely
because its application prefers clipboard paste. Coordinate clicking remains a
fallback only when exact field restoration failed or no field was captured.

Version 1.0.33 refreshes the Electron opt-in when field capture is missing,
checks window-level focus when the application root provides none, and validates
the focused element's PID. Paste resolves Command-V through the current keyboard
layout rather than assuming US key code 9. No new permission, signing identity
or automatic retry is introduced. Run `make keyboard-layout-smoke` without
changing the user's input source; it covers US, Dvorak, French, Bulgarian and
Bulgarian Phonetic. This does not constitute a live Codex test: current computer
use tools disallow controlling Codex, and no workaround should bypass that rule.

Local 1.0.33 verification (2026-10-24): universal app build, text/recognition/
language/foundations contracts, five keyboard layouts, ten native live insertion
cases and Chrome address-bar delivery after switching applications passed. Chrome
readback contained the probe exactly once and the other app remained unchanged.
Six synthetic audio fixtures selected the expected language and recognized all
23 checked terms; the long Bulgarian fixture still had 9.5% raw word error rate.
No user microphone recording was retained, and no additional model was downloaded.

## Automated checks

| Surface or behavior | Result | Evidence |
| --- | --- | --- |
| macOS Accessibility and hotkey startup | Passed on local Mac | Stable-signed installed app log: trusted AX and active event tap |
| Floating node footprint | Passed on local Mac | `make node-smoke` |
| Clipboard text, HTML, custom type, multiple items | Passed on local Mac | `make foundations-smoke` |
| User copies new content during clipboard restoration | Passed on local Mac | `make foundations-smoke` |
| Cancelled operation gate | Passed in isolation | `make foundations-smoke` |
| English/Bulgarian cleanup and preserved phrases | Passed on local Mac | `make text-smoke` |
| Messages, Chrome, CapCut compatibility routing | Source contract passed | `make insertion-smoke`; not a live paste test |
| Native editor: same field, different field/window/app | Passed on local Mac | `make live-insertion-smoke`: exact original selection replaced once; other fields unchanged |
| Point-only editor: newer click, 15-minute-old operation anchor | Passed on local Mac | Production injector + disposable external editor, actual content inspected |
| Long Bulgarian clipboard delivery to moved window | Passed on local Mac | Production injector + disposable external editor, full content present once |
| Resized point-only destination | Passed on local Mac | Refused stale coordinates; transcript retained on clipboard |
| Cancelled delivery, missing destination, newer user copy | Passed on local Mac | Live harness checks destination and pasteboard values |
| Chrome textarea and contenteditable with focus moved to another field | Passed on local Mac | `--browser-check` + native UI inspection: confirmed; original field updated, other field unchanged |
| Chrome address bar | Passed on local Mac in 1.0.32 | `--surface-check chrome --switch-app`: actual field readback, original destination updated once, newer application's editor unchanged |
| Hermes composer | Passed on local Mac in 1.0.32 | `--surface-check hermes --switch-app`: actual composer readback, no message submitted, newer application's editor unchanged |

## Remaining surface checks

These are not marked as verified merely because Cmd-V was posted or a source
contract passed. For each surface, dictate into a disposable field, change focus
while decoding, and confirm both destination and clipboard content afterward.

| Surface | Status | Specific risk |
| --- | --- | --- |
| TextEdit / Notes | Specific apps not yet live-tested in this pass | Native AppKit editor fixture passed; app-specific AX behavior may differ |
| Chrome textarea | Live field-focus test passed | Switching browser tabs/navigation is not covered by that test |
| Chrome rich-text editor / Notion | Chrome contenteditable passed; Notion not tested | AX may not expose a readable value; paste can be unverified |
| Electron apps / Codex | Capture opt-in implemented; end-to-end dictation still needs user acceptance | Accessibility element identity may change on rerender |
| Terminal | Not yet live-tested | Editing state and command line differ from text fields |
| Messages / Viber / CapCut | Not yet live-tested | Some custom fields only accept clipboard paste |

## Manual acceptance checklist

1. Dictate a short phrase into a disposable TextEdit or Notes document; confirm
   it appears once and the clipboard returns to its previous content.
2. Dictate a long phrase into a browser textarea, switch to another app during
   decoding, and confirm it lands only in the original textarea.
3. Repeat in a rich-text editor and Terminal. If the app says **Paste sent,
   unverified**, inspect the destination and use History > Copy if needed.
4. Enable **Review and edit before inserting**. Confirm the preview opens without
   hovering, remains editable, and Insert uses the original destination.
5. Disable the floating node and repeat preview. Confirm the editor opens in the
   app window and Discard leaves the destination unchanged.
6. Start a longer dictation, press Escape during decoding, and confirm no text
   appears later. Repeat after starting a newer recording.

## Known limitations

- A paste sent to an editor with no readable Accessibility value cannot be
  confirmed automatically. The app reports it as unverified and does not retry,
  because a retry could duplicate text.
- Automatic undo is disabled until the destination can prove that the last edit
  still belongs to Dictator-md. Use the destination's own undo only after checking
  what it would remove.
- Whisper inference continues in the background after Escape; the cancelled
  result is isolated and cannot be inserted, but GPU/CPU work is not yet aborted.
- Live microphone tests on every third-party app require those apps and field
  states. This checkpoint does not claim universal insertion coverage.
- Point-only editors lack a durable field identity. Window movement is supported;
  resized/closed windows are refused rather than clicked at guessed coordinates.
  Navigation, browser tab replacement, or a destroyed field can require recovery
  via the clipboard or History. The overlay does not override operating-system
  restrictions or guarantee delivery to every possible custom editor.

## Required regression gate

Run `make live-insertion-smoke` from an Accessibility-authorized local agent or
terminal. It opens two disposable native editor processes, uses the actual
`FocusTracker` and `TextInjector`, and asserts text, selection, duplicate count,
destination and clipboard behavior (19 checks). It restores the initial clipboard
and closes its fixtures afterward. CI source-contract checks are supplementary;
headless runners cannot replace this GUI/permission-dependent test.

Run `make delivery-contract-smoke` for exact readback edge cases and
`make recognition-smoke` for backward-compatible History delivery serialization.
`make delivery-history-ui-build` builds a disposable preview of the production
History rows without loading the ASR engine or writing test dictations to the
user's History. Its Finish Verification menu restores the test clipboard.

For Chrome, serve `scripts/fixtures/insertion.html` locally, open it in a disposable
native Chrome window, focus a field, then run the compiled test with
`--browser-check`. Move focus before sending Return to the test process. Inspect
both fields afterward; it refuses to target a non-test browser window.

For the Chrome address bar, open a disposable New Tab window and focus its empty
address bar. For Hermes, focus an empty Message composer. Run the compiled
test with `--surface-check chrome --switch-app` or
`--surface-check hermes --switch-app`, then send Return to the test process.
The test switches to a disposable external editor, calls the real injector,
reads the original field and confirms the external editor was not modified.
It never submits a search or message. Remove the unsent probe afterward.
These tests prove the tested states, not every popup, navigation or rerender.

Implementation reference: [Electron accessibility](https://github.com/electron/electron/blob/main/docs/tutorial/accessibility.md).
