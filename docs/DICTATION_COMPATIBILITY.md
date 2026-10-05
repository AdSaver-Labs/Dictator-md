# Dictation Compatibility Checkpoint

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
destination and clipboard behavior (10 cases). It restores the initial clipboard
and closes its fixtures afterward. CI source-contract checks are supplementary;
headless runners cannot replace this GUI/permission-dependent test.

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
