# Dictation Compatibility Checkpoint

Version 1.0.29 introduces conservative target verification. If the original field
cannot be reidentified, Dictator-md does not guess at another field. A transcript
is still saved in History, with a Copy command in the menu bar and floating node.

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

## Live field checks still required

These are not marked as verified merely because Cmd-V was posted or a source
contract passed. For each surface, dictate into a disposable field, change focus
while decoding, and confirm both destination and clipboard content afterward.

| Surface | Status | Specific risk |
| --- | --- | --- |
| TextEdit / Notes | Not yet live-tested | AX selected-text readback varies by editor |
| Chrome textarea | Not yet live-tested | Browser focus can change between recording and paste |
| Chrome rich-text editor / Notion | Not yet live-tested | AX may not expose a readable value; paste can be unverified |
| Electron apps / Codex | Not yet live-tested | Accessibility element identity may change on rerender |
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
