#!/usr/bin/env bash
# Tests for statusline.sh cost aggregation. Builds a fake projects/teams layout
# in a temp dir, points transcript_path at it, and asserts the emitted $cost.
# Everything the team logic needs is derived from transcript_path, so no real
# ~/.claude files are touched. ANSI colors are stripped before comparison.
set -u
SCRIPT="$(cd "$(dirname "$0")" && pwd)/statusline.sh"
. "$(dirname "$0")/test-lib.sh"

LEAD=abc12345-0000-0000-0000-000000000000  # first8 = team suffix "abc12345"
MATE=def67890-1111-1111-1111-111111111111

WORK=()
cleanup() { for d in "${WORK[@]}"; do rm -rf "$d"; done; }
trap cleanup EXIT


# one assistant message line: id output_tokens (sonnet -> output rate 15/Mtok)
asst() { printf '{"type":"assistant","message":{"id":"%s","model":"claude-sonnet-5","usage":{"output_tokens":%s}}}\n' "$1" "$2"; }

# base scenario: primary ($0.15) + teammate ($0.30) + team config. Echoes ROOT.
build() {
  local root proj
  root="$(mktemp -d "${TMPDIR:-/tmp}/statusline-test.XXXXXX")"
  WORK+=("$root")
  proj="$root/projects/-proj"
  mkdir -p "$proj" "$root/teams/session-abc12345"
  asst m1 10000 > "$proj/$LEAD.jsonl"
  { printf '{"parentUuid":null,"teamName":"session-abc12345","agentName":"mate","type":"user"}\n'
    asst m2 20000; } > "$proj/$MATE.jsonl"
  printf '{"name":"session-abc12345","members":[]}' > "$root/teams/session-abc12345/config.json"
  echo "$root"
}

cost_of() { # root -> the $cost number for the lead transcript
  printf '{"transcript_path":"%s","cwd":"%s","model":"claude-sonnet-5","context_window":{"used_percentage":25,"context_window_size":200000,"current_usage":{"input_tokens":1000}}}' \
    "$1/projects/-proj/$LEAD.jsonl" "$1" \
    | bash "$SCRIPT" | strip | grep -oE '\$[0-9.]+' | tr -d '$'
}

render() { printf '%s' "$1" | bash "$SCRIPT" 2>&1 | strip; }
ctx_of() { render "$1" | grep -oE 'ctx: [0-9]+%' | head -1; }
rate5h_of() { render "$1" | grep -oE '5h: [0-9]+%( \([^)]*\))?' | head -1; }
rate7d_of() { render "$1" | grep -oE '7d: [0-9]+%( \([^)]*\))?' | head -1; }

check() { # expected actual label
  if [[ "$2" == "$1" ]]; then
    printf 'PASS  %-40s -> %s\n' "$3" "$2"; pass=$((pass+1))
  else
    printf 'FAIL  %-40s -> got=[%s] want=[%s]\n' "$3" "$2" "$1"; fail=$((fail+1))
  fi
}

ROOT="$(build)"
check '0.45' "$(cost_of "$ROOT")" 'teammate cost is summed in'

ROOT="$(build)"
mkdir -p "$ROOT/projects/-proj/$MATE/subagents"
asst m3 40000 > "$ROOT/projects/-proj/$MATE/subagents/agent-1.jsonl"
check '1.05' "$(cost_of "$ROOT")" "teammate's own subagents summed in"

ROOT="$(build)"
rm -rf "$ROOT/teams"
check '0.15' "$(cost_of "$ROOT")" 'no team config -> teammate ignored'

ROOT="$(build)"
{ printf '{"teamName":"session-ffffffff","agentName":"x","type":"user"}\n'
  asst m9 80000; } > "$ROOT/projects/-proj/other.jsonl"
check '0.45' "$(cost_of "$ROOT")" 'unrelated teamName excluded'

# empty model must not shift later fields (tab-IFS collapses empty fields)
ROOT="$(build)"
NULL_MODEL_JSON=$(printf '{"transcript_path":"%s","cwd":"%s","model":null,"context_window":{"used_percentage":25,"context_window_size":200000,"current_usage":{"input_tokens":1000}}}' \
  "$ROOT/projects/-proj/$LEAD.jsonl" "$ROOT")
check 'ctx: 25%' "$(ctx_of "$NULL_MODEL_JSON")" 'null model does not shift fields'
check '0.45' "$(render "$NULL_MODEL_JSON" | grep -oE '\$[0-9.]+' | tr -d '$')" 'null model keeps cost segment'

# fractional percentage must not break bash integer arithmetic
ROOT="$(build)"
FRAC_JSON=$(printf '{"transcript_path":"%s","cwd":"%s","model":"claude-sonnet-5","context_window":{"used_percentage":25.5,"context_window_size":200000,"current_usage":{"input_tokens":1000}}}' \
  "$ROOT/projects/-proj/$LEAD.jsonl" "$ROOT")
check 'ctx: 25%' "$(ctx_of "$FRAC_JSON")" 'fractional used_percentage floored'

# usage lines with null/unknown models are skipped, not fatal to the cost jq
ROOT="$(build)"
printf '{"type":"assistant","message":{"id":"m4","model":null,"usage":{"output_tokens":10000}}}\n' \
  >> "$ROOT/projects/-proj/$LEAD.jsonl"
check '0.45' "$(cost_of "$ROOT")" 'null model line does not abort cost'

ROOT="$(build)"
printf '{"type":"assistant","message":{"id":"m5","model":"claude-zephyr-9","usage":{"output_tokens":10000}}}\n' \
  >> "$ROOT/projects/-proj/$LEAD.jsonl"
check '0.45' "$(cost_of "$ROOT")" 'unknown model family skipped'

# rate_limits segments render with used_percentage and, if present, resets_at
ROOT="$(build)"
RATE_JSON=$(printf '{"transcript_path":"%s","cwd":"%s","model":"claude-sonnet-5","context_window":{"used_percentage":25,"context_window_size":200000,"current_usage":{"input_tokens":1000}},"rate_limits":{"five_hour":{"used_percentage":42,"resets_at":%s},"seven_day":{"used_percentage":18}}}' \
  "$ROOT/projects/-proj/$LEAD.jsonl" "$ROOT" "$(( $(date +%s) + 3600 ))")
check '5h: 42% (1h 0m)' "$(rate5h_of "$RATE_JSON")" '5h segment shows pct and resets_at'
check '7d: 18%' "$(rate7d_of "$RATE_JSON")" '7d segment shows pct without resets_at'

# absent rate_limits hides both segments
ROOT="$(build)"
NO_RATE_JSON=$(printf '{"transcript_path":"%s","cwd":"%s","model":"claude-sonnet-5","context_window":{"used_percentage":25,"context_window_size":200000,"current_usage":{"input_tokens":1000}}}' \
  "$ROOT/projects/-proj/$LEAD.jsonl" "$ROOT")
check '' "$(rate5h_of "$NO_RATE_JSON")" 'no rate_limits -> 5h segment hidden'
check '' "$(rate7d_of "$NO_RATE_JSON")" 'no rate_limits -> 7d segment hidden'

summary
