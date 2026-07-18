#!/usr/bin/env bash
# Tests for fable-orchestrator.sh: pipe sample SessionStart JSON, assert whether
# the orchestrator prompt is injected (inject) or not (silent).
set -u
HOOK="$(cd "$(dirname "$0")" && pwd)/fable-orchestrator.sh"
. "$(dirname "$0")/../test-lib.sh"

run() { # json -> inject|silent|unknown
  local out ctx
  out=$(printf '%s' "$1" | bash "$HOOK")
  [[ -z "$out" ]] && { echo silent; return; }
  ctx=$(jq -r '.hookSpecificOutput.additionalContext // ""' <<<"$out")
  [[ -n "$ctx" ]] && echo inject || echo "unknown:$out"
}

check() { # expected json label
  local got; got=$(run "$2")
  if [[ "$got" == "$1" ]]; then
    printf 'PASS  %-32s -> %s\n' "$3" "$got"; pass=$((pass+1))
  else
    printf 'FAIL  %-32s -> got=%s want=%s\n' "$3" "$got" "$1"; fail=$((fail+1))
  fi
}

check inject '{"model":"claude-fable-5"}'   'fable model'
check silent '{"model":"claude-opus-4-8"}'  'opus model'
check silent '{"model":"claude-sonnet-5"}'  'sonnet model'
check silent '{"source":"clear"}'           'model absent'
check silent '{}'                            'empty input'

summary
