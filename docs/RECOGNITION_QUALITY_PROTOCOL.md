# Local Recognition Quality Protocol

## 1.0.37 Verification Checkpoint

Local Mac verification on 2026-10-24: the opening/independent-phrase check
identified a synthetic EN-to-BG switch that the old overlapping-window decision
silently accepted. Version 1.0.37 requires review for that recording. Across 19
other shared synthetic recordings, all language/review decisions passed and all
19 raw transcripts matched 1.0.36 exactly, with 32/32 checked specialist terms.
The same 19 language/review checks also passed with the already-installed Silero
VAD enabled. Text, recognition/persistence, 48 language/sampling/recovery checks,
1,200 cold/primed keyboard lookups, five keyboard layouts and seven delivery
readback contracts passed. The universal app built and passed strict signature
verification.
This preserves the baseline, including its spelling errors; it does not prove
improved mixed-language word accuracy. The existing English output guard still
requires Latin-script output, so Bulgarian names in English can be transliterated.

A broad default-vocabulary reorder was tested and rejected after quiet Bulgarian
regressed. This version keeps the first-pass glossary order. Technical
phonetic cues only prioritize existing names during bounded uncertain-segment
rechecks; explicit saved vocabulary takes precedence over glossary cues. No
fuzzy replacement rules or new model downloads were added.

Final local Mac verification on 2026-10-26: all 19 production-injector live
external-editor checks passed. Four full ASR-to-History-to-original-editor cases
passed (manual EN/BG and Auto EN/BG), with confirmed exact clipboard replacement
and no edits to the other fields. Review/retry, expiry, discard, cancellation,
stale acceptance and no pre-acceptance History/clipboard writes also passed.
Personal History was untouched by the tests. The cold-start keyboard lookup,
48 language/sampling/recovery and 33 recognition/persistence checks passed again.

The paste, focus, clipboard, microphone, hotkey, permissions, signing and engine
delivery files are unchanged. Installed 1.0.37 retained trusted Accessibility,
Right Option (61), the existing medium model in Auto mode, and the 92x5 collapsed
node footprint. Strict installed-signature verification passed. This is not a
new physical-microphone or every-third-party-editor compatibility claim.

## Boundary

RecognitionVocabulary, RecognitionQuality and PersonalCorrections improve the
existing local Whisper engine. They must not change microphone permissions,
signing, hotkeys, captured destinations, TextInjector, FocusTracker or node
window behaviour. No additional model, paid API or network request is required.

## Vocabulary

- Resolve the recording's English/Bulgarian language before packing hints.
- Use the loaded Whisper tokenizer, not character or word-count estimates.
- Pack complete entries below 224 tokens (216 with safety headroom).
- Never let an oversized term push out all remaining shorter terms.
- Explicit custom terms and confirmed spellings outrank observed terms.
- Auto must retain Bulgarian candidates; English excludes Cyrillic hints.
- A glossary is recognition context, not an instruction-following prompt.
- Glossary cues may select spellings for a recheck but never fuzzy-rewrite text.
- A medicine or brand glossary is not medical advice or guaranteed recognition.

## Conservative Cleanup

Use NSSpellChecker's automatic correction API, never select a replacement by
sorting its suggestion list by edit distance. For Bulgarian, an automatic
replacement may only remove one adjacent duplicated letter from a word and
must also be approved by the system dictionary. Arbitrary deletions, verb
changes and specialist-word guesses require a user-confirmed correction.
All NSSpellChecker access, including its available-language list, belongs on
the main thread. Missing language support leaves the original text intact.

Specialist spelling sources for the small recognition-only glossary:
[Bulgarian Drug Agency](https://www.bda.bg/images/stories/documents/new_registered/201910/3.pdf)
and [Medical University Sofia](https://mu-sofia.bg/wp-content/uploads/2018/08/CMH_2010_2011.pdf).
These sources establish spelling, not recognition accuracy or medical guidance.

## Learning

1. History's original recognition identifies whether the ASR or cleanup failed.
2. A user explicitly confirms a short recognized phrase and its intended spelling
   in Vocabulary or through History's correction button.
3. Store the pair, language, optional context and confirmation date locally in
   corrections.json. This is personalization, not acoustic model training.
4. Apply only exact Unicode word/phrase matches, against the original text once.
   Prefer longer and context-specific rules. Do not cascade replacements.
5. Never change numeric values through a saved correction. Do not introduce
   Cyrillic into English. Raw mode bypasses personal text replacements.
6. The user can disable corrections or delete a rule. A failed disk write must
   not appear as a successful save. No external keystroke/clipboard monitoring.
7. Automatically observed history terms remain lower-confidence suggestions,
   not confirmed correction pairs. They must never trigger fuzzy substitutions.

## Recording Language Invariant

Snapshot the user's Auto/EN/BG choice at recording start. A later settings change
must not reinterpret the current recording or replace its model while busy.
Manual EN/BG never invokes language detection. Auto uses a detection-only copy:
scan at most the first 60 seconds for sustained non-silent audio, keep 300 ms
pre-roll, and examine eight seconds followed by at most thirty if uncertain.
For recordings with at least five seconds of detection audio, cross-check a
three-second opening phrase as well. Confident conflicting EN/BG evidence must
return uncertainty and use the existing review/retry flow, not force one
language. When at least seven seconds are available and the opening is confident,
the comparison phrase starts at second three, so the same opening cannot
dominate both votes. A short opening alone cannot establish a lock. This is a guard against
some code-switching failures, not a per-word bilingual recognizer. Manual modes
continue to bypass all automatic language decisions.
Conservative energy gating is not a learned voice detector; it may retain noise.
Detection gain is bounded to 8x. Never trim or amplify the actual decode buffer
through this sampling step. An unsupported Slavic classification is never
sufficient evidence for Bulgarian. Keep translation disabled. Test language
choice separately from word accuracy, including borrowed first words and noise.

## Uncertain Language Recovery

- An unresolved Auto decision produces an English *draft*, not an English lock.
  Require review before insertion, including when the draft is empty.
- The review window offers explicit EN/BG re-transcription with the same model
  and original audio. A retry returns to review, never automatically inserts.
- Keep the original target snapshot. Never recapture focus from the review UI.
- Retain audio only in RAM for five minutes from the first review; retries do
  not extend the deadline. The retention cap is ten minutes of 16 kHz Float32
  audio (38.4 MB). Longer recordings still have an editable draft, without retry.
- Clear retained audio on Insert, Discard, Escape, expiry and the next recording.
  Expiry keeps the editable draft and disables retry. In-flight inference can
  finish using its local copy; cancelled results must fail the operation gate.
- Each retry invalidates older callbacks. Accept only from the preview state,
  record History once on acceptance and use the unchanged delivery routine.
- Logs contain timing/probabilities/status, never microphone samples or text.

## Bounded Rechecks

Recheck at most two uncertain segments of 1-12 seconds, with a combined maximum
of 15 seconds. Do not recheck a segment already decoded with beam search.
Use the same model, resolved language, captured segment audio and a smaller beam.
Do not broadcast duplicate segment callbacks or insert intermediate results.
Accept only a meaningful mean token log-probability improvement, plausible
length, preserved numeric/spoken-number tokens, and no repeated phrase.
Scores are heuristics, not calibrated probabilities of correctness. Keep the
first result whenever a retry fails any guard. Users can disable rechecks.

## Privacy

History optionally keeps original recognition alongside the final text in its
existing local store, subject to the same history retention and clearing action.
Correction pairs are intentionally saved separately and survive clearing
History. No raw microphone audio is saved, uploaded or logged. Diagnostics may
include timing, token counts and retry counts, never dictated content.
The audio harness generates synthetic fixtures only when explicitly run.

Mixed-language fixtures concatenate language-appropriate synthetic voices. This
does not reproduce one speaker switching languages or their accent. The harness
refuses stale cached fixtures when reference definitions change. Set
`DICTATOR_TEST_CONFLICT=1` with a separate scratch directory to exercise a
conflicting EN/BG recording that must require review. Report spelling/word
errors separately from language and review decisions, even when the latter pass.

## Verification

Run make recognition-smoke, make text-smoke, make auto-language-smoke,
make foundations-smoke, make insertion-smoke and make app.
Compile the audio harness with make recognition-audio-build, then run:

```sh
/tmp/dictatormd-smoke/verify-recognition-audio /path/to/existing/multilingual-model.bin /tmp/recognition-fixtures /tmp/recognition-results.json
```

Use the same recordings for before/after comparisons. Track English and
Bulgarian separately: raw word errors, exact specialist terms, language choice,
latency, repetitions and numerical changes. Synthetic speech is a smoke test,
not evidence of performance on a particular user's accent, slang or whispers.
Repeat with `DICTATOR_TEST_VAD=1` to exercise the installed VAD when available;
the default no-VAD run is a separate silence/quiet-audio stress test.
Add failed real recordings only with explicit consent and anonymization.
`make auto-language-smoke` also tests sampling bounds, quiet openings and RAM
expiry. `make language-review-engine-build` builds an isolated engine test; run
its `/tmp/dictatormd-smoke/verify-language-review-engine` executable with the same
model and fixture directory. It exercises review, retry, discard, expiry,
cancellation and the absence of pre-acceptance History/clipboard delivery.
Its test-only entry points are excluded from production builds and its storage
root is temporary. `make language-review-ui-build` renders the production review
view with inert callbacks for compact/expanded UI and button checks.
Before handoff verify the correction controls in the installed app and run a
real external-editor insertion smoke test with unchanged production delivery.
