# Propagate Noctalia's current wallpaper to stylix, so the apps re-theme to
# match the shell. Noctalia owns the wallpaper and colours its own UI live from
# it; stylix derives the app palette (kitty/GTK/Qt) from a wallpaper at BUILD
# time, so keeping them in sync means a rebuild. This script:
#   1. asks Noctalia for the wallpaper currently shown on the focused output,
#   2. copies it over the tracked stylix source in the local flake checkout,
#   3. runs `nixos-rebuild switch`, which makes stylix re-derive the palette.
#
# Pick a wallpaper first via Noctalia's panel (SUPER+W), then run this
# (SUPER+SHIFT+W) to make it permanent and re-theme every app.
#
# Env overrides:
#   FLAKE_DIR   local flake checkout   (default ~/desktop-nix)
#
# Note: the committed wallpaper is also what `system.autoUpgrade` (which builds
# from git main) restores, so a synced wallpaper persists only until the next
# auto-upgrade unless the change is committed.

flake_dir="${FLAKE_DIR:-$HOME/desktop-nix}"
target="$flake_dir/modules/nixos/desktop/wallpaper.png"
host="$(cat /etc/hostname)"

# Resolve the wallpaper effective on the focused output (falls back to the first
# output, then to Noctalia's default). Per-output paths need a connector name.
monitor="$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name' | head -n1)"
[ -n "$monitor" ] || monitor="$(hyprctl monitors -j | jq -r '.[0].name')"

selected="$(noctalia msg wallpaper-get "$monitor" 2>/dev/null | head -n1)"
[ -f "$selected" ] || selected="$(noctalia msg wallpaper-get 2>/dev/null | head -n1)"

if [ ! -f "$selected" ]; then
    notify-send -u critical "Wallpaper sync" "Could not resolve the current wallpaper from Noctalia"
    exit 1
fi

if [ ! -e "$flake_dir/flake.nix" ]; then
    notify-send -u critical "Wallpaper sync" \
        "No flake checkout at $flake_dir; set FLAKE_DIR. Palette not rebuilt."
    exit 1
fi

cp -f "$selected" "$target"
notify-send "Wallpaper sync" "Rebuilding to re-derive the palette…"

if sudo nixos-rebuild switch --flake "$flake_dir#$host"; then
    notify-send "Wallpaper sync" "Apps re-themed from $(basename "$selected")"
else
    notify-send -u critical "Wallpaper sync" "Rebuild failed; Noctalia changed but apps did not"
    exit 1
fi
