# AGENTS.md - Dictator MD

## Project Purpose

Dictator MD is no longer only a local macOS dictation utility. Its long-term direction is a local/private voice platform for humans and agents:

- dictate anywhere on the computer;
- talk with one agent by voice;
- join open voice rooms/channels with multiple agents;
- create podcast-like conversations with agents;
- ground conversations in documents, transcripts, and project memory;
- preserve privacy-first, local-first behavior wherever possible.

## Engineering Owner

Codex owns the code implementation lane for this repository when working through the OpenClaw team.

Dexter remains operator/orchestrator. Alej remains product owner.

## Required Routing Gate

Before any meaningful Dictator MD code change through OpenClaw:

1. Confirm the active execution runtime is Codex/OpenAI Codex, or record why Codex is unavailable.
2. If Codex is unavailable, record the exact blocker in the active OpenClaw task before using a fallback.
3. Do not route Dictator MD implementation to Jacques, Hermes/Jack, QA, or any sub-agent/helper unless Alej explicitly approves that exact run.
4. Keep the proof package with the change: diff summary, tests/builds or blocker, privacy note, and current-dictation regression note.
5. Run `scripts/verify-codex-routing.sh` before claiming the repo is ready for OpenClaw-managed Dictator MD development.

## Local Mac Codex Compatibility

Alej may also run Codex locally on a Mac against this same repository.

Local Mac Codex work is allowed and should follow this file as normal repo guidance. These OpenClaw routing rules do not install hooks, block commits, change remotes, or prevent local Mac Codex from implementing and pushing changes.

To avoid collisions between the VPS/OpenClaw clone and Alej's Mac clone:

1. Pull or rebase from `origin/main` before starting work.
2. Keep each change small and push promptly after verification.
3. If Git rejects a push because the other environment pushed first, fetch and rebase instead of force-pushing.
4. Never use force-push or destructive resets unless Alej explicitly approves.
5. Mention in the completion summary whether the work was done from OpenClaw/Codex or local Mac Codex.

## Current Product Invariant

Do not break the current dictation product:

- macOS menu bar app;
- microphone and accessibility permissions;
- global hotkey/toggle;
- local Whisper.cpp transcription;
- text insertion into any app;
- privacy-first/no-telemetry behavior.

Any voice-platform expansion must preserve this working core.

## Architecture Direction

Prefer incremental modules over broad rewrites:

1. `Dictation Mode` - existing local transcription flow.
2. `Voice Console` - live voice conversation with one agent.
3. `Voice Rooms` - multi-agent open conversation spaces.
4. `Study / Podcast Mode` - source-grounded brief, debate, critique, deep dive, and human-joins-live sessions.
5. `Adapters` - OpenClaw, Codex, Hermes/Jack, MCP, HTTP, CLI, and local mock adapters.

Keep agent adapters pluggable. Do not hardcode Dexter, OpenClaw, or any single provider as the only supported participant.

## Implementation Rules

- Inspect existing code before editing.
- Keep changes small and reversible.
- Add or update tests with behavior changes.
- Run the relevant build/test command before claiming completion.
- Document architecture decisions for major module boundaries.
- Keep local/offline and cloud/agent-connected modes clearly separated.
- Do not store sensitive audio/transcripts without explicit settings and user control.
- Do not add external services as required dependencies without approval.

## First Preferred Slice

If no narrower task is specified, start with:

1. Define a `VoiceSession` domain model.
2. Add a local transcript/session store abstraction.
3. Add a mock agent adapter.
4. Add a minimal Voice Console path separate from the current dictation flow.
5. Verify the existing dictation flow still builds and behaves as before.

## Proof Standard

Completion requires:

- code diff summary;
- test/build output or exact blocker;
- privacy-impact note;
- regression note for current dictation behavior;
- next smallest proof step.
