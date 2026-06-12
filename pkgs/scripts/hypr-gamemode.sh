# Toggle "gamemode": disable animations, blur, shadows, gaps and rounding for a
# performance boost, then restore on the next toggle via `hyprctl reload`.
#
# Already file-write free (uses hyprctl keyword); the only migration change is
# the flag location, moved out of ~/.config/ml4w/settings into the writable
# $XDG_STATE_HOME/desktop-nix path. Bound to a key in Ticket 11 (gaming).

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/desktop-nix"
state_file="$state_dir/gamemode-enabled"
mkdir -p "$state_dir"

if [ -f "$state_file" ]; then
    hyprctl reload
    rm -f "$state_file"
    notify-send "Gamemode deactivated" "Animations and blur enabled"
else
    hyprctl --batch "\
        keyword animations:enabled 0;\
        keyword decoration:shadow:enabled 0;\
        keyword decoration:blur:enabled 0;\
        keyword general:gaps_in 0;\
        keyword general:gaps_out 0;\
        keyword general:border_size 1;\
        keyword decoration:rounding 0"
    touch "$state_file"
    notify-send "Gamemode activated" "Animations and blur disabled"
fi
