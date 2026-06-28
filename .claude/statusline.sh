#!/bin/bash
input=$(cat)

# Extract all values in a single jq call (tab-separated)
IFS=$'\t' read -r cwd model ctx_pct total_s tok transcript_path < <(
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
      ($ctx.used_percentage // 0),
      (($ctx.context_window_size // 0) | fmt),
      (if $actual > 0 then $actual | fmt else "0" end),
      (.transcript_path // "")
    ] | @tsv'
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

# Colors
R='\033[0m'
GREEN='\033[38;2;63;185;80m'
PEACH='\033[38;2;232;130;90m'
FOLDER='\033[38;2;250;200;80m'

# Build output
folder="${cwd##*/}"
parts="${FOLDER}${folder}${R}"
[ -n "$branch" ] && parts="$parts | ${GREEN}${branch}${R}"
[ -n "$model" ]  && parts="$parts | ${PEACH}${model}${R}"

if [ "$ctx_pct" != "0" ]; then
  capped=$((ctx_pct > 50 ? 50 : ctx_pct))
  r=$((capped * 255 / 50))
  g=$(((50 - capped) * 255 / 50))
  parts="$parts | ctx: \033[38;2;${r};${g};0m${ctx_pct}%${R} (${tok}/${total_s})"
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
