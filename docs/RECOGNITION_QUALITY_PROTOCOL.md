# Local Recognition Quality Protocol

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
Add failed real recordings only with explicit consent and anonymization.
Before handoff verify the correction controls in the installed app and run a
real external-editor insertion smoke test with unchanged production delivery.
