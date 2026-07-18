#!/usr/bin/env bash
# Tests for subagent-model-policy.sh: pipe sample Agent tool_input JSON, assert
# the decision (deny | allow:<picked-model> | silent passthrough).
set -u
HOOK="$(cd "$(dirname "$0")" && pwd)/subagent-model-policy.sh"
. "$(dirname "$0")/../test-lib.sh"

run() { # json -> deny|allow:<model>|silent|unknown
  local out dec mdl
  out=$(printf '%s' "$1" | bash "$HOOK")
  [[ -z "$out" ]] && { echo silent; return; }
  dec=$(jq -r '.hookSpecificOutput.permissionDecision // ""' <<<"$out")
  case "$dec" in
    deny)  echo deny ;;
    allow) mdl=$(jq -r '.hookSpecificOutput.updatedInput.model // ""' <<<"$out"); echo "allow:$mdl" ;;
    *)     echo "unknown:$out" ;;
  esac
}

check() { # expected json label
  local got; got=$(run "$2")
  if [[ "$got" == "$1" ]]; then
    printf 'PASS  %-32s -> %s\n' "$3" "$got"; pass=$((pass+1))
  else
    printf 'FAIL  %-32s -> got=%s want=%s\n' "$3" "$got" "$1"; fail=$((fail+1))
  fi
}

# Unset/inherit/fable on a known type -> auto-assigned.
check allow:sonnet '{"tool_input":{"subagent_type":"Explore"}}'                              'Explore, no model'
check allow:sonnet '{"tool_input":{"subagent_type":"claude-code-guide","model":"inherit"}}'  'guide, inherit'
check allow:opus   '{"tool_input":{"subagent_type":"Plan","model":""}}'                      'Plan, empty'
check allow:opus   '{"tool_input":{"subagent_type":"Plan","model":"fable"}}'                 'Plan, fable overridden'
# Unknown type without an explicit model -> denied.
check deny         '{"tool_input":{"subagent_type":"general-purpose"}}'                       'unknown type, no model'
check deny         '{"tool_input":{"subagent_type":"general-purpose","model":"fable"}}'       'unknown type, fable'
# Deliberate non-fable model -> left untouched (silent passthrough).
check silent       '{"tool_input":{"subagent_type":"general-purpose","model":"opus"}}'        'explicit opus passthrough'
check silent       '{"tool_input":{"subagent_type":"Explore","model":"haiku"}}'               'explicit haiku passthrough'

summary
