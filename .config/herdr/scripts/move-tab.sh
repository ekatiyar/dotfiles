#!/usr/bin/env bash
# Pick a tab from another workspace and move it into the current one, keeping
# its label and split layout.
set -uo pipefail

tab="${HERDR_ACTIVE_TAB_ID:-${HERDR_TAB_ID:-}}"
sock="${HERDR_SOCKET_PATH:-$HOME/.config/herdr/herdr.sock}"

snapshot=$(herdr api snapshot)
ws=$(jq -r --arg t "$tab" '.result.snapshot.tabs[] | select(.tab_id == $t) | .workspace_id' <<<"$snapshot")
[ -n "$ws" ] || exit 1

# Field 1 is the tab id, field 2 a pane to preview; both hidden from the list.
rows=$(jq -r --arg w "$ws" --arg h "$HOME" '
  def pad($w): . + ((" " * ($w - length)) // "");
  .result.snapshot as $s
  | ($s.workspaces | map({key: .workspace_id, value: .}) | from_entries) as $ws
  | [ $s.tabs[]
      | select(.workspace_id != $w)
      | . as $t
      | (first($s.panes[] | select(.tab_id == $t.tab_id)) // {}) as $p
      | [ .tab_id,
          ($p.pane_id // ""),
          "\($ws[.workspace_id].label // .workspace_id)/\(.label // .tab_id)",
          (if (.pane_count // 1) == 1 then "1 pane" else "\(.pane_count) panes" end),
          ($p.cwd // "" | if startswith($h) then "~" + .[($h | length):] else . end),
          (if ($p.terminal_title_stripped // "") == "" then "(shell)" else $p.terminal_title_stripped end)
        ]
    ]
  | (map(.[2] | length) | max // 0) as $wloc
  | (map(.[4] | length) | max // 0) as $wcwd
  | .[]
  | "\(.[0])\t\(.[1])\t\(.[2] | pad($wloc))  \(.[3])  \(.[4] | pad($wcwd))  \(.[5])"' <<<"$snapshot")

picked=$(printf '%s' "$rows" | fzf \
  --delimiter=$'\t' --with-nth 3.. --accept-nth 1 \
  --layout=reverse --no-sort --cycle --info=inline-right \
  --prompt 'move tab> ' \
  --footer 'enter: move here | ctrl-p: toggle preview' \
  --preview 'herdr pane read {2} --source recent-unwrapped --lines 60' \
  --preview-window 'down,60%,hidden,follow' \
  --bind 'ctrl-p:toggle-preview')
picked=${picked%%$'\t'*}
[ -n "$picked" ] || exit 0

label=$(jq -r --arg t "$picked" '.result.snapshot.tabs[] | select(.tab_id == $t) | .label // ""' <<<"$snapshot")

# The CLI has no tab move, so export the split tree over the socket and replay
# it pane by pane. Splitting each subtree's first leaf in pre-order rebuilds
# the same tree; moved panes get new ids, tracked in new_id.
layout=$(jq -nc --arg t "$picked" '{id: "move-tab", method: "layout.export", params: {tab_id: $t}}' \
  | socat -t2 - UNIX-CONNECT:"$sock" | jq -c '.result.layout')
[ -n "$layout" ] && [ "$layout" != null ] || exit 1

focused=$(jq -r '.focused_pane_id' <<<"$layout")
plan=$(jq -r '
  def leaf: if .type == "pane" then .pane_id else (.first | leaf) end;
  def steps: if .type == "pane" then empty else
    [(.second | leaf), (.first | leaf), .direction, .ratio], (.first | steps), (.second | steps) end;
  (.root | leaf), (.root | steps | @tsv)' <<<"$layout")

focus_flag() { [ "$1" = "$focused" ] && echo --focus || echo --no-focus; }

declare -A new_id
{ read -r first; mapfile -t steps; } <<<"$plan"
out=$(herdr pane move "$first" --workspace "$ws" --new-tab --label "$label" "$(focus_flag "$first")") || exit 1
new_id[$first]=$(jq -r '.result.move_result.pane.pane_id' <<<"$out")
dest=$(jq -r '.result.move_result.pane.tab_id' <<<"$out")

for step in "${steps[@]}"; do
  IFS=$'\t' read -r pane target dir ratio <<<"$step"
  out=$(herdr pane move "$pane" --tab "$dest" --split "$dir" --target-pane "${new_id[$target]}" \
    --ratio "$ratio" "$(focus_flag "$pane")") || exit 1
  new_id[$pane]=$(jq -r '.result.move_result.pane.pane_id' <<<"$out")
done
