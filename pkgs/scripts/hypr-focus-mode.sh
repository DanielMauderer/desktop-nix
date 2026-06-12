# Toggle focus ("zen") mode for the ACTIVE workspace only.
#
# Redesign of the old focus-mode.sh: instead of rewriting a tracked config file
# (focus-mode-rules.conf) inside ~/.config/hypr, this applies the workspace rule
# live with `hyprctl keyword workspace` and keeps its on/off flag in
# $XDG_STATE_HOME/desktop-nix (a writable path, off the read-only HM tree).
#
# The "restore" values must match the general/decoration defaults in
# modules/home/desktop/hyprland.nix (gaps_in 4, gaps_out 8, border_size 3).

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/desktop-nix"
state_file="$state_dir/focusmode-enabled"
mkdir -p "$state_dir"

if [ -f "$state_file" ]; then
    # Disable: restore the normal layout for the workspace we zeroed out.
    ws_id="$(cat "$state_file")"
    rm -f "$state_file"
    hyprctl keyword workspace \
        "$ws_id, gapsin:4, gapsout:8, bordersize:3, border:true, rounding:true"
    pkill -SIGUSR1 waybar || true
    notify-send -i preferences-system "Focus mode off" "Workspace $ws_id restored"
else
    # Enable: strip all spacing/border on the active workspace, hide the bar.
    ws_id="$(hyprctl activeworkspace -j | jq '.id')"
    echo "$ws_id" >"$state_file"
    hyprctl keyword workspace \
        "$ws_id, gapsin:0, gapsout:0, bordersize:0, border:false, rounding:false"
    pkill -SIGUSR1 waybar || true
    notify-send -i preferences-system "Focus mode on" \
        "Workspace $ws_id — gaps removed, bar hidden"
fi
