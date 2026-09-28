set -euo pipefail

focused_window=$(niri msg --json focused-window)
[[ $focused_window != null ]] || exit 0
window_id=$(jq -er '.id' <<< "$focused_window")

niri msg action fullscreen-window --id "$window_id"
niri msg action toggle-windowed-fullscreen --id "$window_id"
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
