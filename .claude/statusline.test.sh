#!/usr/bin/env bash
# Tests for statusline.sh rendering and the shared statusline-lib defs. The
# script reads only its stdin payload, so each case is just a JSON object and an
# expected segment. cwd points outside a repo to keep the branch segment out.
# ANSI colors are stripped before comparison.
set -u
LIB="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$LIB/statusline.sh"
. "$(dirname "$0")/test-lib.sh"

NOW=$(date +%s)

# Merges its argument over a healthy baseline payload so each case states only
# the field under test. cwd is /tmp: outside a repo, so no branch segment.
payload() {
  jq -c -n --argjson patch "$1" --argjson now "$NOW" '
    {
      cwd: "/tmp",
      model: {id: "claude-opus-5", display_name: "Opus 5 (1M context)"},
      effort: {level: "high"},
      context_window: {
        total_input_tokens: 430000,
        context_window_size: 1000000,
        used_percentage: 43
      },
      cost: {total_cost_usd: 16.3433},
      prompt_cache: {warm: true, ttl: "1h", hit_ratio: 0.973, expires_at: ($now + 2280)}
    } * $patch'
}

render() { payload "$1" | bash "$SCRIPT" 2>&1 | strip; }
seg()    { render "$1" | tr '|' '\n' | grep -oE "$2" | head -1 | sed 's/[[:space:]]*$//'; }
raw()    { payload "$1" | bash "$SCRIPT" 2>&1; }

check_re() { # extended-regex actual label
  if [[ "$2" =~ $1 ]]; then
    printf 'PASS  %-42s -> %s\n' "$3" "$2"; pass=$((pass+1))
  else
    printf 'FAIL  %-42s -> got=[%s] want=~[%s]\n' "$3" "$2" "$1"; fail=$((fail+1))
  fi
}

check() { # expected actual label
  if [[ "$2" == "$1" ]]; then
    printf 'PASS  %-42s -> %s\n' "$3" "$2"; pass=$((pass+1))
  else
    printf 'FAIL  %-42s -> got=[%s] want=[%s]\n' "$3" "$2" "$1"; fail=$((fail+1))
  fi
}

# --- whole line ------------------------------------------------------------
check 'tmp | Opus 5 (high) | ctx: 43% (430k/1.0m) | $16.34 | cache 37m' \
  "$(render '{}')" 'full line renders every segment'


# --- cost, from cost.total_cost_usd ----------------------------------------
check '$16.34' "$(seg '{}' '\$[0-9.]+')"                                'cost rounded to cents'
check '$16'    "$(seg '{"cost":{"total_cost_usd":16}}' '\$[0-9.]+')"    'whole dollars drop the decimals'
check '$0.01'  "$(seg '{"cost":{"total_cost_usd":0.006}}' '\$[0-9.]+')" 'sub-cent total rounds up, still shown'
check ''       "$(seg '{"cost":null}' '\$[0-9.]+')"                     'absent cost hides the segment'
check ''       "$(seg '{"cost":{"total_cost_usd":0}}' '\$[0-9.]+')"     'zero cost hides the segment'


# --- cache: hit_ratio colors the label, the value is time to expiry --------
check 'cache 37m' "$(seg '{}' 'cache .*')" 'warm cache shows minutes remaining'
check_re '^cache [0-9]{1,2}s$' "$(seg "{\"prompt_cache\":{\"expires_at\":$((NOW + 45))}}" 'cache .*')" \
  'under a minute shows seconds'
check 'cache cold' "$(seg '{"prompt_cache":{"warm":false}}' 'cache .*')" 'not warm reads cold'
check 'cache cold' "$(seg "{\"prompt_cache\":{\"expires_at\":$((NOW - 10))}}" 'cache .*')" \
  'already expired reads cold'
check 'cache cold' "$(seg '{"prompt_cache":{"warm":false,"expires_at":null}}' 'cache .*')" \
  'null expires_at does not break the countdown'
check '' "$(seg '{"prompt_cache":null}' 'cache.*')" 'absent prompt_cache hides the segment'

# The label carries the hit-rate color; the countdown stays uncolored.
hue() { raw "$1" | grep -oE $'\x1b\\[38;2;[0-9;]+m''cache' | head -1 | sed $'s/\x1b\\[38;2;//; s/mcache//'; }
check '0;255;0'   "$(hue '{"prompt_cache":{"hit_ratio":1}}')"    '100% hit rate is pure green'
check '17;238;0'  "$(hue '{"prompt_cache":{"hit_ratio":0.98}}')" 'gradient ramps down from green'
check '153;102;0' "$(hue '{"prompt_cache":{"hit_ratio":0.82}}')" 'mid range is a blend, not a tier'
check '255;0;0'   "$(hue '{"prompt_cache":{"hit_ratio":0.70}}')" 'the 70% floor is pure red'
check '255;0;0'   "$(hue '{"prompt_cache":{"hit_ratio":0.55}}')" 'below the floor stays red'


# --- rate limits: present values render; unavailable values disappear ------
check '5h: 42% (1h 5m)' \
  "$(seg "{\"rate_limits\":{\"five_hour\":{\"used_percentage\":42.8,\"resets_at\":$((NOW + 3960))}}}" '5h:.*')" \
  '5h segment shows percentage and time remaining'
check '7d: 18% (5d 2h)' \
  "$(seg "{\"rate_limits\":{\"seven_day\":{\"used_percentage\":18,\"resets_at\":$((NOW + 442800))}}}" '7d:.*')" \
  '7d segment shows percentage and time remaining'
check '5h: 42%' \
  "$(seg '{"rate_limits":{"five_hour":{"used_percentage":42}}}' '5h:.*')" \
  'rate limit without reset time still renders percentage'
check '' "$(seg '{"rate_limits":null}' '5h:.*')" 'absent rate limits hide the segment'
check '' "$(seg '{"rate_limits":{"five_hour":{}}}' '5h:.*')" 'missing percentage hides the segment'


# --- context window --------------------------------------------------------
check 'ctx: 43% (430k/1.0m)' "$(seg '{}' 'ctx.*')" 'context from the prebuilt percentage'
check 'ctx: 25% (50k/200k)' \
  "$(seg '{"context_window":{"used_percentage":25.9,"total_input_tokens":50000,"context_window_size":200000}}' 'ctx.*')" \
  'fractional percentage floored'
check '' "$(seg '{"context_window":{"used_percentage":null}}' 'ctx.*')" \
  'null percentage hides the segment'


# --- degraded payloads must not break the layout ---------------------------
check 'tmp | ctx: 43% (430k/1.0m) | $16.34 | cache 37m' \
  "$(render '{"model":null,"effort":null}')" 'null model drops only its own segment'
check 'tmp | Opus 5 | ctx: 43% (430k/1.0m) | $16.34 | cache 37m' \
  "$(render '{"effort":null}')" 'no effort level still prints the model'
check 'tmp | Opus 5 (high)' "$(render '{"context_window":null,"cost":null,"prompt_cache":null}')" \
  'first render, before any API response'


# --- rate table ------------------------------------------------------------
# $/Mtok straight from rate_for, so a stale price fails here rather than
# quietly skewing every cost the subagent rows print.
rate() { jq -rn -L "$LIB" --arg m "$1" "include \"statusline-lib\"; rate_for(\$m).$2"; }

check '2'    "$(rate claude-sonnet-5 input)"      'sonnet input rate'
check '10'   "$(rate claude-sonnet-5 output)"     'sonnet output rate'
check '0.25' "$(rate claude-fable-5-1 hit)"       'fable cache read is 0.025x'
check '50'   "$(rate claude-fable-5-1 output)"    'fable output rate'
check '0.50' "$(rate claude-opus-5 hit)"          'opus cache read is 0.1x'
check '6.25' "$(rate claude-opus-5 w5m)"          'opus 5m write is 1.25x'
check '10'   "$(rate claude-opus-5 w1h)"          'opus 1h write is 2x'
check '1'    "$(rate claude-haiku-4-5 input)"     'haiku input rate'
check '5'    "$(rate 'claude-opus-5[1m]' input)"  '1M context carries no premium'
check 'null' "$(rate claude-zephyr-9 input)"      'unknown family has no rate'


# --- shared lib formatters -------------------------------------------------
lib() { jq -rn -L "$LIB" "include \"statusline-lib\"; $1"; }
check '5d 2h'  "$(lib '439200 | dur')" 'multi-day duration shows days and hours'
check '1h 5m'  "$(lib '3900 | dur')"   'multi-hour duration shows hours and minutes'
check '60m'    "$(lib '3600 | dur')"   'one hour remains cache-compatible'
check '1m'     "$(lib '90 | dur')"     'duration floors to whole minutes'
check '45s'    "$(lib '45 | dur')"     'under a minute reads as seconds'
check 'now'    "$(lib '0 | dur')"      'expired duration reads now'
check '12.35'  "$(lib '12.34567 | usd')" 'usd rounds to the nearest cent'

summary
