# Recognition v1.0.31 Verification

Local Mac Codex implementation, 2026-10-05. No new ASR model was downloaded.

## Source and Local Checks

- Universal arm64/x86_64 build passed with the existing stable signing certificate.
- 29 recognition/correction checks passed: script filtering, token packing,
  correction scope, persistence/deletion, numeric safety and bounded retry policy.
- Text-correction checks passed, including personal corrections and Raw bypass.
- Auto-language decisions: 10 cases passed. Dictation foundations and existing
  insertion contracts passed.
- Installed app's correction UI was tested at 900x700 and 1400x900. Real AX
  actions edited fields, saved/deleted a disposable rule, verified its disk
  persistence, and opened/closed the History correction sheet.
- All ten production TextInjector live editor checks passed, covering original
  field/window/application restoration, clipboard delivery and failure recovery.
  Posted-paste cases were read back by the harness; their production outcome can
  still be sentUnverified when the destination does not expose a readable AX value.
- TextInjector, FocusTracker, HotkeyMonitor, PermissionManager, AudioCapture and
  FloatingNodeView source files were not changed.
- Installed app reported AX=true, a working event tap for key code 61, and the
  existing multilingual ggml-medium.bin loaded in Auto mode.

## Identical Synthetic Audio Comparison

Six fixtures were generated using already available macOS Daria (Bulgarian) and
Samantha (English) voices. Both builds used the exact same Float32 16kHz audio,
the already installed multilingual medium model, Auto language and VAD disabled.
The baseline used the previous bridge and previous default vocabulary plus
Openclaw/Hermes. Results are raw ASR, before grammar correction, not a comparison
of a user's microphone/accent or their private personal vocabulary.

| Fixture | Baseline Word Error Rate | Updated Word Error Rate | Baseline Target Terms | Updated Target Terms |
| --- | ---: | ---: | ---: | ---: |
| Bulgarian medicine/brand | 20.0% | 0.0% | 1/2 | 2/2 |
| English medicine/brand | 10.0% | 0.0% | 1/2 | 2/2 |
| Bulgarian cities | 0.0% | 0.0% | 3/3 | 3/3 |
| English technical terms | 0.0% | 0.0% | 4/4 | 4/4 |
| Long Bulgarian note | 11.1% | 9.5% | 4/5 | 5/5 |
| Long English note | 6.0% | 0.0% | 5/7 | 7/7 |

All six language choices were correct in both builds. Target terms improved
from 18/23 to 23/23, including diclofenac/Doppelherz and their Bulgarian spellings.
The long Bulgarian fixture still contained errors. No perfect accuracy claim is
supported. Clean fixtures did not trigger the low-confidence recheck; its policy
guards were tested independently. Recognition on real accents, slang, whispering
and noisy low-confidence speech remains a user-testing requirement.

Timing varied with shader warmup and concurrent compilation; this run does not
establish a speed improvement. The update adds small local vocabulary/correction
work and only bounded optional second-pass computation, with no cloud calls.

## Privacy

No user audio was recorded for the benchmark or uploaded. Synthetic audio and
raw benchmark results stay in temporary local files. History's original-text
field follows existing local retention. Approved correction pairs remain locally
in corrections.json and can be deleted individually. Diagnostics contain counts
and timings, not transcript contents.

## Next Proof

Have the user read the same Bulgarian/English specialist passages normally, then
quietly, and compare raw versus final History text. Add a confirmed correction
for a failed term and retest it, without changing the existing speech model.
