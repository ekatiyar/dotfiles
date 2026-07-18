#!/usr/bin/env bash
# Tests for plan-adherence.sh: assert it emits valid additionalContext JSON whose
# hookEventName matches the event arg (defaulting to PostToolUse when omitted).
set -u
HOOK="$(cd "$(dirname "$0")" && pwd)/plan-adherence.sh"
. "$(dirname "$0")/../test-lib.sh"

check() { # label want-event args...
  local label="$1" want="$2"; shift 2
  local out evt ctx
  out=$(bash "$HOOK" "$@" </dev/null)
  if ! jq -e . >/dev/null 2>&1 <<<"$out"; then
    printf 'FAIL  %-24s -> invalid JSON: %s\n' "$label" "$out"; fail=$((fail+1)); return
  fi
  evt=$(jq -r '.hookSpecificOutput.hookEventName // ""' <<<"$out")
  ctx=$(jq -r '.hookSpecificOutput.additionalContext // ""' <<<"$out")
  if [[ "$evt" == "$want" && -n "$ctx" ]]; then
    printf 'PASS  %-24s -> %s\n' "$label" "$evt"; pass=$((pass+1))
  else
    printf 'FAIL  %-24s -> evt=%s ctx_len=%s want=%s\n' "$label" "$evt" "${#ctx}" "$want"; fail=$((fail+1))
  fi
}

check 'SessionStart arg' SessionStart SessionStart
check 'PostToolUse arg'  PostToolUse  PostToolUse
check 'default (no arg)' PostToolUse

summary
