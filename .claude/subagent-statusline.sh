#!/bin/bash
# Renders one row per running subagent in the agent panel. stdin carries a
# tasks[] array plus the lead session's transcript_path; we emit NDJSON
# ({"id","content"}), mirroring statusline.sh's palette, fmt/short-model helpers,
# and cost aggregation so subagent rows match the lead statusline.
input=$(cat)

_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

transcript_path=$(jq -r '.transcript_path // ""' <<<"$input")
session_dir="${transcript_path%.jsonl}"
proj_dir="${transcript_path%/*}"
lead_sid="${transcript_path##*/}"; lead_sid="${lead_sid%.jsonl}"
team_name="session-${lead_sid:0:8}"

# Cost summed over one or more transcripts; empty string when 0/no files.
# Shares statusline-lib's `cost` def with statusline.sh; failures are silent.
cost_of() {
  [ "$#" -gt 0 ] || { printf ''; return; }
  jq -s -r -L "$_here" 'include "statusline-lib"; cost' "$@" 2>/dev/null || printf ''
}

# Teammate transcripts are loop-invariant (keyed by team_name/proj_dir), so map
# agentName -> transcript once here rather than re-grepping per task.
declare -A agent_file=()
while IFS= read -r tf; do
  an=$(grep -m1 -o '"agentName":"[^"]*"' "$tf" 2>/dev/null)
  an="${an#*agentName\":\"}"; an="${an%\"}"
  [ -n "$an" ] && [ -z "${agent_file[$an]:-}" ] && agent_file[$an]="$tf"
done < <(grep -l -F "\"teamName\":\"$team_name\"" "$proj_dir"/*.jsonl 2>/dev/null)

# One compact task object per line; loop so each task's transcript is read once.
while IFS= read -r task; do
  [ -z "$task" ] && continue
  id=$(jq -r '.id // ""' <<<"$task")
  title=$(jq -r '.label // .name // ""' <<<"$task")
  cost=""
  if [ -n "$session_dir" ]; then
    shopt -s nullglob
    files=()
    [ -n "$id" ] && [ -r "$session_dir/subagents/agent-$id.jsonl" ] &&
      files=("$session_dir/subagents/agent-$id.jsonl")
    # tmux-pane teammates aren't under subagents/; their transcript is top-level.
    # Look it up by agentName, then add its own nested subagents.
    if [ ${#files[@]} -eq 0 ] && [ -n "$title" ]; then
      tf="${agent_file[$title]:-}"
      if [ -n "$tf" ]; then
        tid="${tf##*/}"; tid="${tid%.jsonl}"
        files=("$tf" "$proj_dir/$tid/subagents"/agent-*.jsonl)
      fi
    fi
    shopt -u nullglob
    [ ${#files[@]} -gt 0 ] && cost=$(cost_of "${files[@]}")
  fi

  jq -c -L "$_here" --arg cost "$cost" '
    include "statusline-lib";
    "[0m" as $R |
    "[38;2;232;130;90m" as $PEACH |
    (.label // .name // "") as $title |
    (.model // "") as $m |
    (.contextWindowSize // 0) as $total |
    (.tokenCount // 0) as $tok |
    ( [$title]
      + (if $m != "" then ["\($PEACH)\($m | short_model)\($R)"] else [] end)
      + (if $total > 0
         then
           ($tok * 100 / $total | floor) as $pct |
           ["ctx: \(ctx_color($pct))\($pct)%\($R) (\($tok | fmt)/\($total | fmt))"]
         else [] end)
      + (if ($cost | length) > 0
         then ["\(cost_color($cost | tonumber))$\($cost)\($R)"]
         else [] end)
    ) as $segs |
    {id: .id, content: ($segs | join(" | "))}
  ' <<<"$task"
done < <(jq -c '.tasks // [] | .[]' <<<"$input")
