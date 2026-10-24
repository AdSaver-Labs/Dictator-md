# Dictator-md Platform Readiness Blueprint

Updated: 2026-10-24

## Purpose

This is the execution order for turning Dictator-md from a working macOS product plus Windows/mobile scaffolds into a reliable, local-first multi-platform application. It preserves the current macOS dictation core and does not prescribe a visual redesign.

## Audit Result

| Area | Current reality | Release readiness |
| --- | --- | --- |
| macOS dictation | Local Whisper.cpp, microphone capture, global hotkey, captured-target insertion, history, vocabulary, updater | Working product; needs reliability/performance hardening |
| Windows | Native app/tray/manual hotkey/focus capture/clipboard paste shell | Preview only; no audio capture or ASR |
| iOS | App, app-group storage, custom keyboard shell | Scaffold only; recording and transcription are not implemented |
| Android | App and `InputMethodService` shell | Scaffold only; no microphone capture or ASR |
| Shared core | JSON contracts and duplicated platform data models | Contract layer only; no shared executable behavior |
| Release engineering | macOS DMG + Windows ZIP released; iOS/Android not released | Desktop release path is incomplete for public distribution |

## Checks Run In This Audit

- macOS universal app build: passed.
- macOS node/history/monthly UI checks: passed.
- Compact dashboard sidebar check: failed before this pass because the sidebar could be clipped at 760 x 540; fixed by forcing a scroll surface below the sidebar's required height.
- Mobile scaffold and contract validation: passed before the new compile gates.
- Windows native build and launch: confirmed from the latest successful GitHub Actions run. It verifies launch only, not actual dictation.
- iOS local simulator build: blocked on this Mac because only Xcode Command Line Tools are installed, not full Xcode. CI now builds the generated iOS app and keyboard extension on a full macOS runner.
- Android local build: blocked because no Android SDK/Gradle installation is present. CI now downloads a pinned Gradle distribution and builds the app/IME on a runner with the Android SDK.

## Non-Negotiable Product Rules

1. Do not change the macOS dictation pipeline without a regression test for hotkey, capture, transcription, target restore, insertion fallback, and copied-transcript recovery.
2. No platform may claim "works anywhere" where its operating system denies that capability. iOS cannot replace Apple dictation globally and third-party keyboard extensions cannot access the microphone.
3. Audio and transcripts remain local by default. Cloud or agent features require an explicit, separately visible opt-in.
4. A failed insertion must preserve the transcript, show a recoverable error, and offer copy/retry instead of silently dropping text.
5. Model downloads, updates, and privacy disclosures must use the same product truth across every platform.

## Execution Roadmap

### Research Refresh: Reliability Before Expansion

This review covers 18 relevant products/product families plus inference and
voice-session infrastructure. It is a representative survey, not a claim to
have tested every dictation product on the internet. Public documentation and
source inspection establish implementation ideas, not comparative accuracy.
Closed-source services do not expose their production recognition/insertion
backends. No competitor binaries or new models were installed for this review.

#### Product Evidence and Useful Ideas

| Product | Primary evidence | What is useful for Dictator-md |
| --- | --- | --- |
| Handy | [Paste transaction source](https://github.com/cjpais/Handy/blob/5a9451e70aedc90648ce2befd9d7e0304746f9c1/src-tauri/src/paste_tx/mod.rs), [known clipboard race](https://github.com/cjpais/Handy/issues/502) | Clipboard consumption is asynchronous. Preserve ownership and separate sent from delivered. A clipboard read is not proof of which editor inserted it. |
| FreeFlow | [Captured-target implementation](https://github.com/zachlatta/freeflow/blob/a647469d268d2265f036b4024c509e14eea7fa1c/Sources/AppTextInsertionTarget.swift), [README](https://github.com/zachlatta/freeflow) | Capture field/value/selection, verify edits, bound context, recover last transcript. Cleanup/edit mode normally uses a provider; do not add that dependency to offline dictation. |
| OpenWhispr | [Native paste helper](https://github.com/OpenWhispr/openwhispr/blob/7a6ae826de9ec1caf65f3a6e769475dab2ae829f/resources/macos-fast-paste.swift), [product source](https://github.com/OpenWhispr/openwhispr) | Resolve Command-V for the active keyboard layout; separate platform integrations, notes, models and optional agent features. |
| VoiceInk | [AX reader](https://github.com/Beingpax/VoiceInk/blob/0ac374d0147a9c612f75361c02c43037209df96d/VoiceInk/Features/Dictionary/AutoLearn/AutoLearnAXTextReader.swift), [releases](https://github.com/Beingpax/VoiceInk/releases) | Bounded accessibility queries, editor-specific text access, explicit dictionary correction/import/export and quick history. |
| WhisperDictation | [Upstream README](https://github.com/sam-pop/WhisperDictation) | Commit-on-pause is an optional latency approach. Keep final delivery atomic by default; terminals must never receive speculative rewrites. |
| open-wispr | [Repository](https://github.com/cpiprint/open-wispr) | This is an OpenWhispr fork, not an independent engine. Avoid counting the same architecture twice or merging an older fork indiscriminately. |
| Whispering / Epicenter | [Project transition](https://github.com/braden-w/whispering/blob/main/README.md), [release history](https://github.com/braden-w/whispering/releases) | Native recording lifecycle, recoverable recordings and independently retryable stages. Audio retention must be opt-in here. |
| Wispr Flow | [Context](https://docs.wisprflow.ai/articles/4678293671-Context-Awareness), [privacy](https://wisprflow.ai/privacy) | Context and confirmed edit learning can improve names and formatting. Its cloud processing is not equivalent to our local constraint. |
| Superwhisper | [Modes](https://superwhisper.com/docs/modes/modes), [changelog](https://superwhisper.com/changelog) | Explicit language/model/formatting modes, app-specific workflows, microphone lifecycle and recoverable history. Keep translation separate from transcription. |
| MacWhisper | [Dictation](https://docs.macwhisper.com/article/14-how-to-use-the-dictation-feature), [replacements](https://docs.macwhisper.com/article/37-find-and-replace-in-transcriptions) | Whole-word correction rules, import/export and app profiles. Advanced AI transformations are optional, not a prerequisite for typing. |
| Aqua Voice | [Product](https://aquavoice.com/) | Low-friction delivery is a useful UX target. Marketing accuracy claims are not a benchmark or access to its backend. |
| Buzz | [Source/README](https://github.com/chidiwilliams/buzz) | File-based regression testing, backend separation, export and inspection. Batch transcription features are lower priority than daily dictation. |
| Speech Note | [Source/README](https://github.com/mkiol/dsnote) | Capability-based model catalog and separation of speech recognition, translation and synthesis. Bulgarian support must be checked per engine. |
| FUTO Voice Input / Keyboard | [Language selection](https://docs.keyboard.futo.tech/settings/languagesmodels), [source](https://github.com/futo-org/voice-input) | Limit auto-detection to enabled languages, use Android voice/IME APIs, and publish honest keyboard compatibility. Not every Android keyboard accepts a replacement voice service. |
| Aiko | [Product/FAQ](https://sindresorhus.com/aiko) | Clear on-device processing and transcript recovery/export. Recording transcription is not proof of system-wide insertion. |
| Talon | [Product](https://talonvoice.com/) | Separate command and dictation modes; explicit spoken corrections and accessibility workflows. Commands must not execute from ordinary dictation. |
| Apple Dictation / Microsoft Voice Access | [Apple](https://support.apple.com/en-gb/guide/mac-help/mh40584/mac), [Microsoft corrections](https://support.microsoft.com/en-us/accessibility/windows/voice-access/correct-text-with-voice) | Uncertain-word alternatives, spelling/correction flow, punctuation controls. OS integration is not available identically to third-party apps. |
| Google AI Edge Eloquent | [Publisher's listing](https://apps.apple.com/us/app/google-ai-edge-eloquent/id6756505519) | Guided onboarding, editable personal dictionary and a clear offline/cloud distinction. Verify mobile insertion capabilities rather than assuming global keyboard replacement. |

License boundary: [Handy](https://github.com/cjpais/Handy/blob/main/LICENSE),
FreeFlow and OpenWhispr publish MIT-licensed code. VoiceInk publishes
[GPL-3.0](https://github.com/Beingpax/VoiceInk/blob/main/LICENSE); FUTO Voice Input
uses a [Source First license](https://github.com/futo-org/voice-input/blob/master/LICENSE.md)
with use/distribution restrictions. This pass uses implementation ideas and
platform APIs, not copied GPL/FUTO code. Any later code import needs a specific
license and attribution review; a free download does not make code unrestricted.

#### Findings in Our Current Implementation

- Local diagnostics showed a successful Telegram AX write but missing focused
  fields in Codex, followed by a failed restore or an unverified coordinate paste.
  These are separate from recognition errors. Do not infer that every failure is
  an Accessibility permission issue or change signing to try to repair it.
- Auto could choose Bulgarian from a tiny Bulgarian score when another Slavic
  language won. It also locked a long recording from only two seconds of audio.
- The language was read again at stop, and model reload could interrupt an active
  operation. A UI change could alter an already-started recording's contract.
- Paste used a fixed US physical key. That is not Command-V on every layout.
- Accessibility opt-in was cached by PID indefinitely; a renderer reset could
  leave the cache claiming a usable tree when no field was exposed.
- Existing code already preserves failed transcripts, checks original windows,
  protects newer clipboard copies and avoids blind duplicate-producing retries.
  Keep these behaviors; additional delay alone is not a reliability fix.

#### Implemented in 1.0.33

- [x] Remove unsupported-Slavic-to-Bulgarian coercion and require meaningful
  English/Bulgarian evidence. Examine up to eight opening seconds; broaden to at
  most thirty seconds when uncertain. Manual EN/BG still overrides detection.
- [x] Freeze the language at recording start and defer active-operation model
  replacement. Settings changes take effect on the next recording.
- [x] Refresh the Electron opt-in when focus is missing; check window-level focus
  as well as application focus, validating the owning process.
- [x] Resolve the paste key using the current Command-modified keyboard layout.
  No arbitrary US-key fallback. Add US, Dvorak, French and two Bulgarian checks.

In 1.0.33/1.0.34 Auto still fell back to English when evidence remained uncertain.
The 1.0.35 recovery below replaces silent insertion of that fallback. This is not
a guarantee for one-word, whispered or mixed-language speech.

#### Language Reliability in 1.0.35

Verified locally on 2026-10-24: all nineteen live insertion checks passed with
the unchanged production injector, including exact clipboard replacement,
original-target restoration, delayed AX readback, newer-copy preservation and
secure-field exclusion. The disposable editor's delayed-write setter override
had made AppKit advertise writable AX text in clipboard-only mode; it now lives
in a separate fixture class. An offscreen prerequisite checks remote AX
capabilities before live tests touch focus or clipboard. Point-only targets
remain sent-unverified in production even when fixture readback proves delivery;
these tests do not establish compatibility with every third-party editor.

- Detection-only sampling skips leading near-silence, keeps quiet openings and
  pre-roll, and bounds gain, scan duration and sample size. Full transcription
  still uses the original recording, and translation remains disabled.
- Uncertain Auto results require review. Explicit EN/BG retries reuse RAM audio
  with a five-minute deadline and ten-minute recording cap. Review retains the
  captured destination; only Insert uses the established delivery routine.
- Retry, expiry, discard, cancellation and stale acceptance have isolated real
  engine checks. Recovery never saves audio to disk or downloads another model.
  Review-sheet presentation is checked with the floating node both enabled and
  disabled, including processing and expired-audio states.
- Forty deterministic language/sampling/retention checks and sixteen synthetic
  audio cases cover manual profiles, borrowed openings, quiet speech and long
  leading silence. On the existing medium model the old code selected English
  for Bulgarian after 32 seconds of silence; the new code selected Bulgarian.
  Language selection improved from 15/16 to 16/16 in this small synthetic set.
  This does not establish real-user accuracy: word errors remain, and the
  no-VAD stress test still hallucinated words during a long silent lead-in.
  With the existing Silero VAD enabled, all sixteen language choices and 27
  specialist/number terms passed; the long-silence cases had no added prefix.

Still open: real-user accent/noise evaluation with consent, low-confidence word
review, context-sensitive code-switching and retry after an already-sent result.
No focus, clipboard, signing, permissions or microphone implementation changes
belong to this language slice.

#### Prioritized Remaining Improvements

1.0.34 implements the first delivery slice: local per-item outcome/strategy/reason/
timing, History Copy and explanations, bounded original-draft snapshots,
selection validation, exact readback, secure-field exclusion and clipboard-owner
protection. Native lifecycle/race tests and an actual Hermes app-switch test passed.
See `DICTATION_COMPATIBILITY.md` for evidence and limitations. This is not completion
of every P0 item: diagnostic export, explicit retry/retranscription, all editor
adapters and a complete navigation/minimized/recreated-window matrix remain open.

The following is the overall backlog; the delivery items are partially shipped
as described above, not universally completed. Preserve visual design.
No new model or cloud service is required for P0/P1 unless explicitly stated.

| Priority | Improvement | Acceptance gate |
| --- | --- | --- |
| P0 | Persist delivery status, destination bundle, strategy, timing and reason per history item, with no field contents/audio in diagnostic logs | Failed, unverified and confirmed are distinguishable; export redacts user content |
| P0 | Retain an in-memory operation for explicit retry/copy/retranscribe after failure; never silently retarget | No duplicate insert and no wrong-app insert across retries/cancellation |
| P0 | Snapshot original field value/selection; refuse destructive insertion if that same editor was repurposed during decoding | Changed draft, navigated tab and new chat tests leave unrelated text untouched |
| P0 | Expand editor adapters using supported AX attributes, readable range APIs and bounded focus polling | Live readback in Codex, Hermes, Chrome URL/rich fields, Messages, Viber and CapCut; not just an event-post result |
| P0 | Add secure-field exclusion, ownership checks immediately before dispatch, and lifecycle tests for closed/minimized/recreated windows | No input to password controls or a new foreground application |
| P0 | Preserve uncertain language as uncertainty; offer EN/BG retry using short-lived RAM audio rather than lose or translate a prompt | Same recording can be recovered without speaking again; RAM cleared on dismissal/timeout |
| P0 | Expand automated language tests to ambiguous greetings, silence first, borrowed words, accents, mixed scripts and mode changes | Measure wrong-language rate separately from spelling errors; no manual-mode switch |
| P0 | Audit settings/model state concurrency, including overlapping reload requests and stop/start races | Latest requested model wins; no result from cancelled recording reaches a field |
| P0 | Verify stable identity across install/update; require checksum/signature validation, rollback and matching build metadata | Update preserves permissions/data, rejects stale or mismatched artifacts |
| P1 | Local per-app delivery diagnostics and a disposable compatibility test in onboarding | User can identify capture, recognition or insertion failure without resetting permissions |
| P1 | Bounded speech-aware language sampling that excludes leading silence without clipping whispers | Compare held-out EN/BG recordings, latency and low-volume speech against 1.0.33 |
| P1 | Opt-in local nearby-text vocabulary with strict length/time limits and secure-app exclusions | Proper-name recall improves without leaking context or inserting unspoken words |
| P1 | Dictionary packs for Bulgarian names/places/technical terms, scoped by app/topic | Measure term recall and false substitutions; hints stay inside token budget |
| P1 | Explicit correction learning with import/export, conflict resolution and undo | No automatic promotion of ASR mistakes to trusted replacements |
| P1 | Conservative grammar/punctuation; separate literal/code/prose modes | Negation, numbers, URLs, names and meaning preserved on bilingual fixtures |
| P1 | Expose low-confidence spans and original-vs-cleaned text for review | Confidence described as a heuristic, not a correctness guarantee |
| P1 | Audio-device disconnect/reconnect, Bluetooth route changes, input-level and clipping diagnostics | Capture survives common device changes or reports an actionable error |
| P1 | Quiet-speech calibration with conservative gain/VAD and preserved tail audio | Better measured word accuracy, not merely a larger waveform |
| P1 | Benchmark ASR thread count, warm model reuse, cancellation and memory lifecycle | Report p50/p95 stop-to-text latency and peak memory by duration/language/hardware |
| P1 | Preview transcription during speech using stable prefixes/commit-on-pause behind an opt-in | No duplicated boundary words or speculative text in terminals; final-only remains default |
| P1 | Crash-safe history storage/migrations, aggregates independent of transcript retention | Interrupted writes recover; retention deletion does not corrupt statistics |
| P1 | Accessibility, keyboard-only use, responsive layouts and reduced-motion regression checks | No new design work; existing controls remain usable at compact sizes |
| P2 | Compare other already-compatible runtimes/models only after a measured baseline and user-approved download | Bulgarian capability, storage/RAM, license and real-device WER verified, not inferred from model size |
| P2 | Complete Windows audio/ASR before advertising parity; use UI Automation plus guarded clipboard fallback | Real recordings reach target editors on physical Windows, not placeholder strings |
| P2 | Android IME with local ASR, editor lifecycle handling and bounded model resources | Physical-device battery/thermal/keyboard tests and input-connection recovery |
| P2 | iOS containing-app capture plus keyboard handoff and truthful limitations | Signed real-device tests; no promise to replace Apple's dictation key globally |

#### Inference and Future Voice-Agent References

[whisper.cpp](https://github.com/ggml-org/whisper.cpp/tree/master/examples/stream)
already provides streaming examples, but naive repeated windows are not a
production merge policy. [Whisper-Streaming](https://github.com/ufal/whisper_streaming)
provides a local-agreement approach for stable prefixes. Evaluate these with the
existing model first. [Argmax/WhisperKit](https://github.com/argmaxinc/argmax-oss-swift)
and [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) are runtime candidates,
not drop-in promises of better Bulgarian accuracy or zero resource cost.

Voice-agent work remains separate and unimplemented:

1. Versioned VoiceSession and provider adapters for OpenClaw, Hermes and others;
   authenticated connections and explicit local/remote data boundaries.
2. Streaming ASR -> agent -> streaming TTS, with measured response latency.
3. Echo cancellation, turn detection, interruptions/barge-in and reconnects.
4. Tool-action approval, conversation retention/deletion and per-agent access.
5. Only then multi-participant rooms, moderation, billing and operational costs.

[Pipecat](https://docs.pipecat.ai/pipecat/learn/speech-input) and
[LiveKit Agents](https://docs.livekit.io/agents/) offer relevant transport,
turn-taking and interruption architecture. Open-source frameworks do not make
hosted inference or network infrastructure free. Dictation must keep working
offline if every agent provider is unavailable.

#### Release Evidence Standard

For each reliability release: run deterministic tests, real native field
readbacks, browser/editor checks where permitted, synthetic EN/BG audio, and
report the limits. Codex UI automation is blocked by the current test environment;
do not bypass that boundary or claim a Codex live test passed. Ask for a short
user acceptance test after installation. Synthetic speech is not evidence of
perfect recognition of the user's accent. Public superiority claims require a
matched, consented, held-out benchmark across products, which this survey is not.

### Earlier Cross-Platform Roadmap

The original platform checklist below records broader work. The dated research
refresh above is the current dictation priority order; old unchecked items may
now be partially covered by the subsequent compatibility/recognition protocols.

### P0 - Guardrails and Proof (implemented in this pass)

- [x] Fix the compact-height sidebar clipping path without changing the dashboard design.
- [x] Stop console logging raw dictated text from the correction stage.
- [x] Add platform contract verification.
- [x] Add iOS compilation to CI using XcodeGen and an unsigned simulator build.
- [x] Add Android debug compilation to CI with a pinned Gradle version.
- [ ] Add macOS unit-test execution to CI through the generated Xcode project.
- [ ] Add Windows unit tests for focus capture, clipboard preservation, and hotkey fallback.

### P1 - macOS Reliability and Speed

- [ ] Replace the current JSON-only memory store with SQLite plus daily aggregates, keeping transcript history user-deletable and analytics uncapped.
- [ ] Add an insertion transaction: capture target + selected range at start, restore once, try AX direct insertion, then clipboard paste, then retry/copy with an explicit error.
- [ ] Preserve and restore the user clipboard after paste, with change-count protection so new clipboard content is never overwritten.
- [ ] Add an insertion diagnostics panel that records target/app/strategy/result but never raw transcript text unless the user explicitly exports diagnostics.
- [ ] Add audio-level calibration, selectable input gain/noise handling, and a quiet-speech test to improve whisper dictation without fabricating audio.
- [ ] Benchmark latency by model, clip duration, language, and hardware class; surface only useful local metrics to the user.
- [ ] Add regression fixtures for duplicate suppression, language guards, punctuation, intonation formatting, custom-term preservation, and English/Bulgarian cleanup.

### P2 - Bulgarian Quality

- [ ] Separate English-only and multilingual model catalogs. English mode must use English-only models; Bulgarian and Auto must use multilingual models only.
- [ ] Add curated Bulgarian dictation fixtures, including colloquial speech, borrowed technical terms, names, punctuation, and common confusions.
- [ ] Evaluate multilingual `small`, `medium`, and `large-v3-turbo` compatible quantizations on held-out Bulgarian clips before selecting defaults.
- [ ] Add user correction pairs: a user-approved correction teaches a local replacement rule, rather than treating every recognized token as trustworthy vocabulary.
- [ ] Add per-language confidence/script guards and an explicit "keep original" escape hatch when cleanup is uncertain.

### P3 - Windows Product Parity

- [ ] Implement WASAPI microphone capture with input-device selection and a visible recording level.
- [ ] Build/link whisper.cpp on Windows, including a model downloader, checksum verification, and multilingual model selection.
- [ ] Replace the placeholder pipeline with real local transcription and shared correction fixtures.
- [ ] Add UI Automation direct insertion where supported; retain clipboard-plus-`SendInput` fallback with clipboard restoration.
- [ ] Add settings, history, vocabulary, language choice, toggle mode, diagnostic log, and recovery UI.
- [ ] Add an MSIX or signed installer, first-run permissions guidance, automatic update path, and Windows signing before broad release.
- [ ] Test real transcription/insertion in Notepad, Chromium, Firefox, VS Code, terminal, Slack/Teams, Telegram/Viber, and password/secure-field failure cases.

### P4 - Android Product

- [ ] Build a real settings/history/vocabulary app around the custom IME.
- [ ] Record only after user action with `RECORD_AUDIO`; use a foreground microphone service and its required visible notification when recording continues outside the app.
- [ ] Run local ASR behind a Kotlin/native boundary, package models as user-managed downloads, and measure memory/thermal behavior on modest devices.
- [ ] Make the IME insert transcripts through `InputConnection`, handle editor restarts, rich editors, and unavailable input connections, and retain a copy/retry fallback.
- [ ] Add offline correction/vocabulary, Android backup/export/delete controls, battery-aware limits, Play Data Safety declarations, and Play internal testing.
- [ ] Test on physical ARM64 and emulator devices across current Android versions and major chat/browser/editor fields.

### P5 - iOS Product

- [ ] Keep recording in the containing app: third-party keyboards cannot use the microphone. The keyboard inserts an already-created transcript only.
- [ ] Implement main-app audio capture, local model lifecycle, transcription, history, language settings, corrections, and a handoff to the keyboard extension via App Group storage.
- [ ] Add a clear Quick Dictate flow: open app/shortcut, record, transcribe locally, then insert from the Dictator-md keyboard in compatible fields.
- [ ] Implement a complete keyboard, including typing keys, next-keyboard control, offline operation without Full Access, and clear supported/unsupported-field messaging.
- [ ] Add iOS privacy manifest, App Store privacy nutrition labels, deletion/export, microphone recording indicator, TestFlight, and real-device testing.
- [ ] Do not promise replacement of Apple's dictation key: Apple does not permit it and custom keyboards cannot access the microphone.

### P6 - Shared Core and Operations

- [ ] Promote the current JSON contracts into versioned migrations and compatibility tests across macOS, Windows, iOS, and Android.
- [ ] Extract deterministic correction, duplicate collapse, language/script guards, statistics, and vocabulary ranking into a portable core with identical test fixtures on each platform.
- [ ] Define a model manifest with SHA256, language capability, quantization, RAM estimate, storage size, and minimum device requirements.
- [ ] Add crash-safe persistence, migration backups, data export/import, per-item delete, clear-all, and restore verification.
- [ ] Add dependency/SBOM/license checks, release provenance, signed artifacts, version-channel policy, rollback instructions, and a public issue template for insertion failures.
- [ ] Add accessibility, keyboard navigation, Dynamic Type/mobile scaling, reduced motion, and localization checks to the test matrix.

## Platform Reality

Android is the closest mobile platform to the desktop promise: a custom IME can be selected for most normal text fields. iOS can offer a good main-app plus keyboard workflow, but cannot globally replace Apple's dictation button; Apple custom keyboard extensions cannot access the microphone. These are OS rules, not missing engineering effort. Apple also requires a functional keyboard without Full Access and a clear recording indication/privacy policy. Android requires correct microphone permissions and foreground-service declarations for microphone access outside a visible activity.

Sources: [Apple custom keyboard documentation](https://developer.apple.com/documentation/uikit/creating-a-custom-keyboard), [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), [Android foreground microphone services](https://developer.android.com/about/versions/11/privacy/foreground-services), [Android InputMethodService](https://developer.android.com/reference/android/inputmethodservice/InputMethodService).

## Definition of Ready for a Public Platform Release

A platform is ready only when all of these are true:

- real local microphone capture and ASR are implemented;
- normal text-field insertion is proven on physical devices plus representative apps;
- permissions, errors, clipboard/transcript recovery, data deletion, and model management work;
- automated builds/tests pass for that platform;
- install/update/signing/privacy/store requirements are complete;
- the platform's limitations are clearly disclosed in-app and in download copy.
