
# Shared jq defs for statusline.sh and subagent-statusline.sh (single source of
# truth for pricing/formatting). Loaded via `jq -L <dir> 'include "statusline-lib"'`.

def fmt:
  if . >= 1000000 then (. / 100000 | floor) as $u
    | "\($u / 10 | floor).\($u % 10)m"
  else "\(. / 1000 | floor)k" end;

def short_model:
  if   test("fable")  then "Fable"
  elif test("opus")   then "Opus"
  elif test("sonnet") then "Sonnet"
  elif test("haiku")  then "Haiku"
  else . end;

# null-safe; unknown model families yield null and are skipped by `cost`.
def rate_for(m):
  (m // "") as $s |
  if   $s | test("fable")  then {input: 10, hit: 1.00, w5m: 12.50, w1h: 20, output: 50}
  elif $s | test("opus")   then {input: 5,  hit: 0.50, w5m: 6.25,  w1h: 10, output: 25}
  elif $s | test("sonnet") then {input: 3,  hit: 0.30, w5m: 3.75,  w1h: 6,  output: 15}
  elif $s | test("haiku")  then {input: 1,  hit: 0.10, w5m: 1.25,  w1h: 2,  output: 5}
  else null end;

# ANSI truecolor helpers shared by both statuslines.
# ctx gradient: green -> red, capped at 50%.
def ctx_color(pct):
  (if pct > 50 then 50 else pct end) as $capped
  | "\u001b[38;2;\($capped * 255 / 50 | floor);\((50 - $capped) * 255 / 50 | floor);0m";

# rate-limit gradient: green -> red, uncapped (0-100%).
def pct_color(pct):
  (if pct > 100 then 100 else pct end) as $capped
  | "\u001b[38;2;\($capped * 255 / 100 | floor);\((100 - $capped) * 255 / 100 | floor);0m";

# cost tiers; "" below $1 hides the color.
def cost_color(c):
  if   c < 1  then ""
  elif c < 2  then "\u001b[38;2;205;127;50m"
  elif c < 4  then "\u001b[38;2;192;192;210m"
  elif c < 8  then "\u001b[38;2;255;215;0m"
  elif c < 16 then "\u001b[38;2;185;242;255m"
  else             "\u001b[38;2;140;200;255m" end;

# Slurped input (jq -s): array of transcript json lines -> cost string ("" at 0).
def cost:
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
  | if . == 0 then "" else "\(.)" end;
