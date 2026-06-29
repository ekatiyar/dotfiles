#!/bin/bash
input=$(cat)

# Extract all values in a single jq call (tab-separated)
IFS=$'\x01' read -r cwd model effort_level ctx_pct total_s tok transcript_path rate_5h reset_5h rate_7d reset_7d < <(
  echo "$input" | jq -r '
    def fmt: if . >= 1000000 then (. / 100000 | floor) as $u
      | "\($u / 10 | floor).\($u % 10)m" else "\(. / 1000 | floor)k" end;
    .context_window as $ctx |
    ($ctx.current_usage // {}) as $cu |
    (($cu.input_tokens // 0) + ($cu.cache_read_input_tokens // 0)
      + ($cu.cache_creation_input_tokens // 0)) as $actual |
    [
      (.cwd // ""),
      ((.model | if type == "object" then .display_name // .id else . end) // ""),
      (.effort.level // ""),
      ($ctx.used_percentage // 0),
      (($ctx.context_window_size // 0) | fmt),
      (if $actual > 0 then $actual | fmt else "0" end),
      (.transcript_path // ""),
      (if .rate_limits.five_hour.used_percentage != null then (.rate_limits.five_hour.used_percentage | floor) else "" end),
      (.rate_limits.five_hour.resets_at // ""),
      (if .rate_limits.seven_day.used_percentage != null then (.rate_limits.seven_day.used_percentage | floor) else "" end),
      (.rate_limits.seven_day.resets_at // "")
    ] | map(tostring) | join("\u0001")'
)

# Aggregate cost from the transcript and any subagent transcripts.
# An empty cost hides the segment; failures are silent by design.
if [ -n "$transcript_path" ] && [ -r "$transcript_path" ]; then
  _session_dir="${transcript_path%.jsonl}"
  shopt -s nullglob
  _cost_files=("$transcript_path" "${_session_dir}/subagents"/agent-*.jsonl)
  shopt -u nullglob

  cost=$(jq -s -r '
    def rate_for(m):
      if   m | test("fable")  then {input: 10, hit: 1.00, w5m: 12.50, w1h: 20, output: 50}
      elif m | test("opus")   then {input: 5,  hit: 0.50, w5m: 6.25,  w1h: 10, output: 25}
      elif m | test("sonnet") then {input: 3,  hit: 0.30, w5m: 3.75,  w1h: 6,  output: 15}
      elif m | test("haiku")  then {input: 1,  hit: 0.10, w5m: 1.25,  w1h: 2,  output: 5}
      else null end;
    [ .[] | select(.type == "assistant" and .message.usage) ] as $msgs |
    [ $msgs | unique_by(.message.id) | .[]
      | .message.model as $m
      | .message.usage as $u
      | (rate_for($m) // empty) as $r
      | ($u.input_tokens // 0)                               * $r.input
      + ($u.cache_read_input_tokens // 0)                    * $r.hit
      + (($u.cache_creation.ephemeral_5m_input_tokens // 0)) * $r.w5m
      + (($u.cache_creation.ephemeral_1h_input_tokens // 0)) * $r.w1h
      + ($u.output_tokens // 0)                              * $r.output
    ]
    | (add // 0) / 1000000
    | . * 1000 | round / 1000
    | if . == 0 then "" else "\(.)" end
  ' "${_cost_files[@]}" 2>/dev/null) || cost=""
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

pct_color() {
  local pct=$(( $1 > 100 ? 100 : $1 ))
  local r=$(( pct * 255 / 100 ))
  local g=$(( (100 - pct) * 255 / 100 ))
  printf '\033[38;2;%d;%d;0m' "$r" "$g"
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
  if [ -n "$effort_level" ]; then
    parts="$parts | ${PEACH}${model} (${effort_level})${R}"
  else
    parts="$parts | ${PEACH}${model}${R}"
  fi
fi

if [ "$ctx_pct" != "0" ]; then
  capped=$((ctx_pct > 50 ? 50 : ctx_pct))
  r=$((capped * 255 / 50))
  g=$(((50 - capped) * 255 / 50))
  parts="$parts | ctx: \033[38;2;${r};${g};0m${ctx_pct}%${R} (${tok}/${total_s})"
fi

if [ -n "$rate_5h" ]; then
  C=$(pct_color "$rate_5h")
  seg="5h: ${C}${rate_5h}%${R}"
  [ -n "$reset_5h" ] && seg="$seg ($(fmt_until "$reset_5h"))"
  parts="$parts | $seg"
fi
if [ -n "$rate_7d" ]; then
  C=$(pct_color "$rate_7d")
  seg="7d: ${C}${rate_7d}%${R}"
  [ -n "$reset_7d" ] && seg="$seg ($(fmt_until "$reset_7d"))"
  parts="$parts | $seg"
fi

if [ -n "$cost" ]; then
  CC=$(echo "$cost" | awk '{
    if ($1 < 1)      printf ""
    else if ($1 < 2) printf "\\033[38;2;205;127;50m"
    else if ($1 < 4) printf "\\033[38;2;192;192;210m"
    else if ($1 < 8) printf "\\033[38;2;255;215;0m"
    else if ($1 < 16) printf "\\033[38;2;185;242;255m"
    else              printf "\\033[38;2;140;200;255m"
  }')
  parts="$parts | ${CC}\$${cost}${R}"
fi

printf '%b' "$parts"
