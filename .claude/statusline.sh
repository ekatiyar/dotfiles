#!/bin/bash
input=$(cat)

_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Extract all values in a single jq call. Unit-separator delimited: unlike tab,
# \x1f is not IFS-whitespace, so empty fields survive the read without shifting.
IFS=$'\x1f' read -r cwd model effort ctx_pct total_s tok transcript_path ctx_c \
  rate_5h reset_5h rate_5h_c rate_7d reset_7d rate_7d_c < <(
  echo "$input" | jq -r -L "$_here" '
    include "statusline-lib";
    .context_window as $ctx |
    ($ctx.current_usage // {}) as $cu |
    (($cu.input_tokens // 0) + ($cu.cache_read_input_tokens // 0)
      + ($cu.cache_creation_input_tokens // 0)) as $actual |
    (.rate_limits.five_hour // {}) as $r5 |
    (.rate_limits.seven_day // {}) as $r7 |
    [
      (.cwd // ""),
      ((.model | if type == "object" then .display_name // .id else . end) // ""
        | sub(" *\\([^)]*\\)$"; "")),
      (.effort.level // "-"),
      ($ctx.used_percentage // 0 | floor),
      (($ctx.context_window_size // 0) | fmt),
      (if $actual > 0 then $actual | fmt else "0" end),
      (.transcript_path // ""),
      ctx_color($ctx.used_percentage // 0 | floor),
      (if $r5.used_percentage != null then ($r5.used_percentage | floor) else "" end),
      ($r5.resets_at // ""),
      (if $r5.used_percentage != null then pct_color($r5.used_percentage | floor) else "" end),
      (if $r7.used_percentage != null then ($r7.used_percentage | floor) else "" end),
      ($r7.resets_at // ""),
      (if $r7.used_percentage != null then pct_color($r7.used_percentage | floor) else "" end)
    ] | map(tostring) | join("\u001f")'
)

# Aggregate cost from the transcript and any subagent transcripts.
# An empty cost hides the segment; failures are silent by design.
if [ -n "$transcript_path" ] && [ -r "$transcript_path" ]; then
  _session_dir="${transcript_path%.jsonl}"
  shopt -s nullglob
  _cost_files=("$transcript_path" "${_session_dir}/subagents"/agent-*.jsonl)

  # tmux-pane teammates (agent-team) are separate top-level sessions, not under
  # subagents/. The team config records no session ids, so find teammate
  # transcripts by the teamName marker they each carry near the top.
  _proj_dir="${transcript_path%/*}"
  _session_id="${transcript_path##*/}"; _session_id="${_session_id%.jsonl}"
  _team_name="session-${_session_id:0:8}"
  _team_cfg="${_proj_dir%/projects/*}/teams/${_team_name}/config.json"
  if [ -r "$_team_cfg" ]; then
    while IFS= read -r _tf; do
      _tid="${_tf##*/}"; _tid="${_tid%.jsonl}"
      _cost_files+=("$_tf")
      _cost_files+=("$_proj_dir/$_tid/subagents"/agent-*.jsonl)
    done < <(grep -l -m1 -F "\"teamName\":\"$_team_name\"" "$_proj_dir"/*.jsonl 2>/dev/null)
  fi
  shopt -u nullglob

  cost=$(jq -s -r -L "$_here" 'include "statusline-lib"; cost' "${_cost_files[@]}" 2>/dev/null) || cost=""
else
  cost=""
fi

branch=$(cd "$cwd" 2>/dev/null && git -c gc.auto=0 branch --show-current 2>/dev/null || echo '')

fmt_until() {
  local secs=$(( $1 - $(date +%s) ))
  [ "$secs" -le 0 ] && echo "now" && return
  local h=$(( secs / 3600 ))
  local m=$(( (secs % 3600) / 60 ))
  if [ "$h" -ge 24 ]; then
    local d=$(( h / 24 ))
    printf '%dd %dh' "$d" $(( h % 24 ))
  elif [ "$h" -ge 1 ]; then
    printf '%dh %dm' "$h" "$m"
  else
    printf '%dm' "$m"
  fi
}

# Colors
R='\033[0m'
GREEN='\033[38;2;63;185;80m'
PEACH='\033[38;2;232;130;90m'
FOLDER='\033[38;2;250;200;80m'

# Build output
folder="${cwd##*/}"
parts="${FOLDER}${folder}${R}"
[ -n "$branch" ] && parts="$parts | ${GREEN}${branch}${R}"
if [ -n "$model" ]; then
  [ -n "$effort" ] && [ "$effort" != "-" ] && model="${model} (${effort})"
  parts="$parts | ${PEACH}${model}${R}"
fi

if [ "$ctx_pct" != "0" ]; then
  parts="$parts | ctx: ${ctx_c}${ctx_pct}%${R} (${tok}/${total_s})"
fi

if [ -n "$rate_5h" ]; then
  seg="5h: ${rate_5h_c}${rate_5h}%${R}"
  [ -n "$reset_5h" ] && seg="$seg ($(fmt_until "$reset_5h"))"
  parts="$parts | $seg"
fi
if [ -n "$rate_7d" ]; then
  seg="7d: ${rate_7d_c}${rate_7d}%${R}"
  [ -n "$reset_7d" ] && seg="$seg ($(fmt_until "$reset_7d"))"
  parts="$parts | $seg"
fi

if [ -n "$cost" ]; then
  CC=$(jq -rn -L "$_here" --arg c "$cost" 'include "statusline-lib"; cost_color($c | tonumber)')
  parts="$parts | ${CC}\$${cost}${R}"
fi

printf '%b' "$parts"
