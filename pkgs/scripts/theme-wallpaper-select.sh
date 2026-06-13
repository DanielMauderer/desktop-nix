# Wallpaper picker (DECISIONS 022). Stylix derives the palette from a wallpaper
# at build time, so changing the wallpaper means a rebuild. This script:
#   1. lets you pick an image (rofi) from the wallpaper directory,
#   2. shows it immediately via swaybg (instant feedback, no wait),
#   3. copies it over the tracked default in the local flake checkout,
#   4. runs `nixos-rebuild switch`, which makes stylix re-derive the palette
#      and re-theme every app.
#
# Env overrides:
#   WALLPAPER_DIR  directory to pick from   (default ~/Pictures/Wallpapers)
#   FLAKE_DIR      local flake checkout      (default ~/desktop-nix)
#
# Note: this needs a local checkout of the config repo to rebuild from; the
# committed wallpaper there is also what `system.autoUpgrade` (which builds
# from git main) restores, so a picked wallpaper persists only until the next
# auto-upgrade unless the change is committed.

wallpaper_dir="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
flake_dir="${FLAKE_DIR:-$HOME/desktop-nix}"
target="$flake_dir/modules/nixos/desktop/wallpaper.png"
host="$(cat /etc/hostname)"

if [ ! -d "$wallpaper_dir" ]; then
    notify-send -u critical "Wallpaper picker" "No wallpaper directory: $wallpaper_dir"
    exit 1
fi

# Collect candidate images and present their basenames in rofi.
mapfile -t images < <(find -L "$wallpaper_dir" -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) | sort)

if [ "${#images[@]}" -eq 0 ]; then
    notify-send -u critical "Wallpaper picker" "No images found in $wallpaper_dir"
    exit 1
fi

choice="$(printf '%s\n' "${images[@]##*/}" | rofi -dmenu -i -p "Wallpaper")"
[ -n "$choice" ] || exit 0

selected="$wallpaper_dir/$choice"
[ -f "$selected" ] || exit 1

# 1. Instant feedback: repaint the live background.
pkill -x swaybg || true
swaybg -i "$selected" -m fill &
disown || true

# 2. Persist + re-theme. Bail clearly if the checkout is missing.
if [ ! -e "$flake_dir/flake.nix" ]; then
    notify-send -u critical "Wallpaper picker" \
        "No flake checkout at $flake_dir; set FLAKE_DIR. Background changed, palette not rebuilt."
    exit 1
fi

cp -f "$selected" "$target"
notify-send "Wallpaper picker" "Rebuilding to re-derive the palette…"

if sudo nixos-rebuild switch --flake "$flake_dir#$host"; then
    notify-send "Wallpaper picker" "Theme rebuilt from $choice"
else
    notify-send -u critical "Wallpaper picker" "Rebuild failed; background changed but palette did not"
    exit 1
fi
