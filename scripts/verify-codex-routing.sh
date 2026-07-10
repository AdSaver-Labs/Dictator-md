#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

required_refs=(
  "AGENTS.md:Codex owns the code implementation lane"
  "AGENTS.md:Required Routing Gate"
  "AGENTS.md:Confirm the active execution runtime is Codex/OpenAI Codex"
  "AGENTS.md:Do not route Dictator MD implementation to Jacques"
  "AGENTS.md:proof package"
  "AGENTS.md:Local Mac Codex Compatibility"
  "AGENTS.md:Local Mac Codex work is allowed"
  "AGENTS.md:fetch and rebase instead of force-pushing"
)

status=0
for pair in "${required_refs[@]}"; do
  file="${pair%%:*}"
  needle="${pair#*:}"
  if grep -Fq "$needle" "$ROOT/$file"; then
    printf 'PASS ref %s contains %s\n' "$file" "$needle"
  else
    printf 'FAIL ref %s missing %s\n' "$file" "$needle"
    status=1
  fi
done

if git -C "$ROOT" ls-files --error-unmatch AGENTS.md >/dev/null 2>&1; then
  printf 'PASS tracked AGENTS.md\n'
else
  printf 'FAIL AGENTS.md is not tracked by git\n'
  status=1
fi

exit "$status"
