set -euo pipefail

state_directory="${XDG_RUNTIME_DIR:-/tmp}/niri-toggle-16-9"
state_file="$state_directory/${NIRI_SOCKET##*/}"
mkdir -p "$state_directory"

if [[ -f $state_file ]]; then
  read -r window_id original_width original_height was_floating <"$state_file"
  niri msg action load-config-file --path "$normal_config"

  if niri msg --json windows | jq --argjson id "$window_id" -e '.[] | select(.id == $id)' >/dev/null; then
    niri msg action toggle-windowed-fullscreen --id "$window_id"
    niri msg action set-window-width --id "$window_id" "$original_width"
    niri msg action set-window-height --id "$window_id" "$original_height"

    if [[ $was_floating == true ]]; then
      niri msg action move-window-to-floating --id "$window_id"
    fi
  fi

  rm -f "$state_file"
  exit 0
fi

focused_window=$(niri msg --json focused-window)
[[ $focused_window != null ]] || exit 0
read -r window_id original_width original_height was_floating <<< "$(
  jq -er '[.id, .layout.window_size[0], .layout.window_size[1], .is_floating] | @tsv' <<< "$focused_window"
)"

rollback() {
  niri msg action load-config-file --path "$normal_config" >/dev/null 2>&1 || true
  rm -f "$state_file"
}
trap rollback ERR

niri msg action load-config-file --path "$zero_gap_config"
niri msg action move-window-to-tiling --id "$window_id"

read -r workspace_id column_index <<< "$(
  niri msg --json windows \
    | jq --argjson id "$window_id" -er '.[] | select(.id == $id) | [.workspace_id, .layout.pos_in_scrolling_layout[0]] | @tsv'
)"

column_size=$(
  niri msg --json windows \
    | jq --argjson workspace "$workspace_id" --argjson column "$column_index" \
      '[.[] | select(.workspace_id == $workspace and .layout.pos_in_scrolling_layout[0] == $column)] | length'
)

if ((column_size > 1)); then
  niri msg action consume-or-expel-window-right --id "$window_id"
fi

niri msg action set-window-width --id "$window_id" "100%"
niri msg action set-window-height --id "$window_id" "100%"
sleep 0.1

read -r available_width available_height <<< "$(
  niri msg --json windows \
    | jq --argjson id "$window_id" -er '.[] | select(.id == $id) | .layout.window_size | @tsv'
)"

target_width=$(((available_height * 16 + 4) / 9))
target_height=$available_height

if ((target_width > available_width)); then
  target_width=$available_width
  target_height=$(((available_width * 9 + 8) / 16))
fi

niri msg action set-window-width --id "$window_id" "$target_width"
niri msg action set-window-height --id "$window_id" "$target_height"
niri msg action focus-window --id "$window_id"
niri msg action center-column
niri msg action toggle-windowed-fullscreen --id "$window_id"
printf '%s\t%s\t%s\t%s\n' \
  "$window_id" "$original_width" "$original_height" "$was_floating" >"$state_file"
trap - ERR
