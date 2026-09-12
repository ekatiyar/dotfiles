#!/usr/bin/env bash
# Pick a pane from another tab and join it into the current one. Enter splits
# vertically (side by side), ctrl-enter horizontally (stacked).
set -uo pipefail

tab="${HERDR_ACTIVE_TAB_ID:-${HERDR_TAB_ID:-}}"
pane="${HERDR_ACTIVE_PANE_ID:-${HERDR_PANE_ID:-}}"

# Field 1 is the raw pane id (hidden from the list); fields 2.. are padded here
# for display, so nothing outside jq has to align them.
rows=$(herdr api snapshot | jq -r --arg t "$tab" --arg h "$HOME" '
  def pad($w): . + ((" " * ($w - length)) // "");
  .result.snapshot as $s
  | ($s.workspaces | map({key: .workspace_id, value: .}) | from_entries) as $ws
  | ($s.tabs       | map({key: .tab_id,       value: .}) | from_entries) as $tb
  | [ $s.panes[]
      | select(.tab_id != $t)
      | $ws[.workspace_id] as $w
      | $tb[.tab_id] as $tt
      | (if ($w.tab_count // 1) <= 1 then ($w.label // $w.workspace_id)
         elif ($tt.pane_count // 1) <= 1 then "\($w.label // $w.workspace_id)/\($tt.label // $tt.tab_id)"
         else "\($w.label // $w.workspace_id)/\($tt.label // $tt.tab_id)/\(.label // (.pane_id | split(":") | last))"
         end) as $loc
      | [ .pane_id,
          $loc,
          (.cwd // "" | if startswith($h) then "~" + .[($h | length):] else . end),
          (if (.terminal_title_stripped // "") == "" then "(shell)" else .terminal_title_stripped end)
        ]
    ]
  | (map(.[1] | length) | max // 0) as $wloc
  | (map(.[2] | length) | max // 0) as $wcwd
  | .[]
  | "\(.[0])\t\(.[1] | pad($wloc))  \(.[2] | pad($wcwd))  \(.[3])"')

out=$(printf '%s' "$rows" | fzf \
  --delimiter=$'\t' --with-nth 2.. --accept-nth 1 \
  --layout=reverse --no-sort --cycle --info=inline-right \
  --prompt 'join> ' \
  --expect=ctrl-j \
  --footer 'enter: vertical | ctrl-enter: horizontal | ctrl-p: toggle preview' \
  --preview 'herdr pane read {1} --source recent-unwrapped --lines 60' \
  --preview-window 'down,60%,hidden,follow' \
  --bind 'ctrl-p:toggle-preview')

{ read -r key; read -r picked; } <<<"$out"
picked=${picked%%$'\t'*}
[ -n "$picked" ] || exit 0

[ "$key" = ctrl-j ] && split=down || split=right
herdr pane move "$picked" --tab "$tab" --split "$split" --target-pane "$pane" --focus
