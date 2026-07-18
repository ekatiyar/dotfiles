#!/usr/bin/env bash
# Tests for subagent-statusline.sh: pipe mock JSON containing a tasks[] array
# through the script and assert the emitted NDJSON rows. ANSI colors are stripped
# before comparison so expected strings stay readable.
set -u
SCRIPT="$(cd "$(dirname "$0")" && pwd)/subagent-statusline.sh"
. "$(dirname "$0")/test-lib.sh"


contents() { printf '%s' "$1" | bash "$SCRIPT" | jq -r '.content' | strip; }
ids()      { printf '%s' "$1" | bash "$SCRIPT" | jq -r '.id'; }
lines()    { printf '%s' "$1" | bash "$SCRIPT" | grep -c .; }

check() { # expected actual label
  if [[ "$2" == "$1" ]]; then
    printf 'PASS  %-40s -> %s\n' "$3" "$2"; pass=$((pass+1))
  else
    printf 'FAIL  %-40s -> got=[%s] want=[%s]\n' "$3" "$2" "$1"; fail=$((fail+1))
  fi
}

FULL='{"tasks":[{"id":"t1","label":"backend-work","model":"claude-sonnet-5","contextWindowSize":200000,"tokenCount":50000}]}'
check 'backend-work | Sonnet | ctx: 25% (50k/200k)' "$(contents "$FULL")" 'full fields: model + ctx %'
check 't1' "$(ids "$FULL")" 'full fields: id'

UNRESOLVED='{"tasks":[{"id":"t2","name":"explorer","status":"pending"}]}'
check 'explorer' "$(contents "$UNRESOLVED")" 'unresolved: name only, no ctx segment'
check 't2' "$(ids "$UNRESOLVED")" 'unresolved: id'

MULTI='{"tasks":[{"id":"a","name":"one"},{"id":"b","name":"two"}]}'
check '2' "$(lines "$MULTI")" 'multiple: one line per task'
check $'a\nb' "$(ids "$MULTI")" 'multiple: id per task in order'

check '0' "$(lines '{"tasks":[]}')" 'empty tasks array: no output'
check '0' "$(lines '{}')"           'tasks key absent: no output'

for pair in 'claude-fable-5:Fable' 'claude-opus-4-8:Opus' 'claude-sonnet-5:Sonnet' 'claude-haiku-4-5-20251001:Haiku'; do
  m="${pair%%:*}"; want="${pair##*:}"
  in="{\"tasks\":[{\"id\":\"x\",\"name\":\"n\",\"model\":\"$m\",\"contextWindowSize\":100000,\"tokenCount\":10000}]}"
  check "n | $want | ctx: 10% (10k/100k)" "$(contents "$in")" "model family: $m -> $want"
done

# --- cost segment: computed from each subagent's transcript, located via the
# top-level (lead) transcript_path + subagents/agent-<id>.jsonl convention ---
TMP=$(mktemp -d)
sid="0000abcd-0000-0000-0000-000000000000"
mkdir -p "$TMP/$sid/subagents"
: > "$TMP/$sid.jsonl"
# 1,000,000 input tokens on Sonnet ($3/M input) => $3
printf '%s\n' '{"type":"assistant","message":{"id":"m1","model":"claude-sonnet-5","usage":{"input_tokens":1000000,"output_tokens":0}}}' \
  > "$TMP/$sid/subagents/agent-t1.jsonl"

COST_IN="{\"transcript_path\":\"$TMP/$sid.jsonl\",\"tasks\":[{\"id\":\"t1\",\"label\":\"backend-work\",\"model\":\"claude-sonnet-5\",\"contextWindowSize\":200000,\"tokenCount\":50000}]}"
check 'backend-work | Sonnet | ctx: 25% (50k/200k) | $3' "$(contents "$COST_IN")" 'cost: appended from subagent transcript'

MISS_IN="{\"transcript_path\":\"$TMP/$sid.jsonl\",\"tasks\":[{\"id\":\"nope\",\"label\":\"x\",\"model\":\"claude-opus-4-8\",\"contextWindowSize\":200000,\"tokenCount\":20000}]}"
check 'x | Opus | ctx: 10% (20k/200k)' "$(contents "$MISS_IN")" 'cost: missing transcript omits segment'

# tmux-pane teammate: transcript lives TOP-LEVEL ($proj/<uuid>.jsonl), not under
# subagents/. Resolver must fall back to matching teamName (session-<first8 of lead
# sid> = session-0000abcd) + the task's agentName. 2,000,000 input tokens sonnet => $6.
mate="1111beef-2222-3333-4444-555555555555"
{ printf '{"type":"user","teamName":"session-0000abcd","agentName":"cancel-fixes"}\n'
  printf '{"type":"assistant","message":{"id":"mm","model":"claude-sonnet-5","usage":{"input_tokens":2000000,"output_tokens":0}}}\n'; } > "$TMP/$mate.jsonl"
TMUX_IN="{\"transcript_path\":\"$TMP/$sid.jsonl\",\"tasks\":[{\"id\":\"$mate\",\"label\":\"cancel-fixes\",\"model\":\"claude-opus-4-8\",\"contextWindowSize\":200000,\"tokenCount\":30000}]}"
check 'cancel-fixes | Opus | ctx: 15% (30k/200k) | $6' "$(contents "$TMUX_IN")" 'cost: tmux teammate top-level transcript resolved'

# a teammate's own nested subagents count too: +1,000,000 sonnet input => $3, total $9.
mkdir -p "$TMP/$mate/subagents"
printf '%s\n' '{"type":"assistant","message":{"id":"ms","model":"claude-sonnet-5","usage":{"input_tokens":1000000,"output_tokens":0}}}' > "$TMP/$mate/subagents/agent-x.jsonl"
check 'cancel-fixes | Opus | ctx: 15% (30k/200k) | $9' "$(contents "$TMUX_IN")" 'cost: tmux teammate + its own subagents summed'

rm -rf "$TMP"

# spaced project dir: teammate transcript paths must survive word-splitting
TMPS=$(mktemp -d "${TMPDIR:-/tmp}/subagent sp.XXXXXX")
sid2="2222abcd-0000-0000-0000-000000000000"
: > "$TMPS/$sid2.jsonl"
mate2="3333beef-2222-3333-4444-555555555555"
{ printf '{"type":"user","teamName":"session-2222abcd","agentName":"spacey"}\n'
  printf '{"type":"assistant","message":{"id":"sm","model":"claude-sonnet-5","usage":{"input_tokens":1000000,"output_tokens":0}}}\n'; } > "$TMPS/$mate2.jsonl"
SPACE_IN="{\"transcript_path\":\"$TMPS/$sid2.jsonl\",\"tasks\":[{\"id\":\"$mate2\",\"label\":\"spacey\",\"model\":\"claude-sonnet-5\",\"contextWindowSize\":200000,\"tokenCount\":20000}]}"
check 'spacey | Sonnet | ctx: 10% (20k/200k) | $3' "$(contents "$SPACE_IN")" 'cost: teammate resolved under spaced proj dir'
rm -rf "$TMPS"

summary
