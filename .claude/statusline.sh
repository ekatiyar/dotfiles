#!/bin/bash
# Renders the main statusline. Every value but the git branch comes straight
# from the harness payload on stdin (fields: code.claude.com/docs/en/statusline),
# so this reads no transcripts. Segments with no data drop out.
input=$(cat)

_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cwd=$(jq -r '.cwd // ""' <<<"$input")
branch=$(cd "$cwd" 2>/dev/null && git -c gc.auto=0 branch --show-current 2>/dev/null || echo '')

jq -r -L "$_here" --arg branch "$branch" '
  include "statusline-lib";
  "[0m"              as $R |
  "[38;2;63;185;80m"  as $GREEN |
  "[38;2;232;130;90m" as $PEACH |
  "[38;2;250;200;80m" as $FOLDER |
  ((.cwd // "") | sub(".*/"; "")) as $folder |
  ((.model | if type == "object" then .display_name // .id else . end) // ""
    | sub(" *\\([^)]*\\)$"; "")) as $model |
  (.effort.level // "") as $effort |
  (.context_window // {}) as $ctx |
  (.prompt_cache // {}) as $pc |
  (.cost.total_cost_usd // 0) as $cost |
  (.rate_limits.five_hour // {}) as $r5 |
  (.rate_limits.seven_day // {}) as $r7 |
  ( ["\($FOLDER)\($folder)\($R)"]

    + (if $branch != "" then ["\($GREEN)\($branch)\($R)"] else [] end)

    + (if $model != ""
       then ["\($PEACH)\($model)\(if $effort != "" then " (\($effort))" else "" end)\($R)"]
       else [] end)

    # used_percentage is input-only, and null or fractional early in a session.
    + (($ctx.used_percentage // 0 | floor) as $pct |
       if $pct > 0
       then ["ctx: \(ctx_color($pct))\($pct)%\($R) (\($ctx.total_input_tokens // 0 | fmt)/\($ctx.context_window_size // 0 | fmt))"]
       else [] end)

    + (if $cost > 0 then ["\(cost_color($cost))$\($cost | usd)\($R)"] else [] end)

    # hit_ratio colors the label; the value is time left before the prefix goes
    # cold, which is the part still worth acting on.
    + (if ($pc.hit_ratio // null) != null
       then (($pc.expires_at // 0) - now | floor) as $left |
            ["\(cache_color($pc.hit_ratio * 100))cache\($R) \(
               if ($pc.warm // false) and $left > 0 then $left | dur else "cold" end)"]
       else [] end)

    + (if ($r5.used_percentage // null) != null
       then ($r5.used_percentage | floor) as $pct |
            ["5h: \(pct_color($pct))\($pct)%\($R)\(
               if ($r5.resets_at // null) != null
               then " (\(($r5.resets_at - now) | dur))" else "" end)"]
       else [] end)

    + (if ($r7.used_percentage // null) != null
       then ($r7.used_percentage | floor) as $pct |
            ["7d: \(pct_color($pct))\($pct)%\($R)\(
               if ($r7.resets_at // null) != null
               then " (\(($r7.resets_at - now) | dur))" else "" end)"]
       else [] end)
  ) | join(" | ")' <<<"$input"
