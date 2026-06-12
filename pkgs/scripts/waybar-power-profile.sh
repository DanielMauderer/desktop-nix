# Waybar custom/power-profile: show and cycle the active power profile.
#
# Replaces the old tuned-adm.sh (Fedora tuned) with power-profiles-daemon,
# which is the NixOS-native power profile service.

profiles=(power-saver balanced performance)
icons=("󰁹" "󰾅" "󰓅")
labels=(Battery Balanced Performance)

if ! command -v powerprofilesctl >/dev/null 2>&1; then
    echo "󰁹 N/A"
    exit 0
fi

current="$(powerprofilesctl get 2>/dev/null || true)"

index=1
for i in "${!profiles[@]}"; do
    if [ "${profiles[$i]}" = "$current" ]; then
        index="$i"
        break
    fi
done

if [ "${1:-}" = "cycle" ]; then
    next=$(((index + 1) % ${#profiles[@]}))
    if powerprofilesctl set "${profiles[$next]}" 2>/dev/null; then
        notify-send "Power Profile" "Switched to: ${labels[$next]}" -t 2000
    else
        notify-send "Power Profile" "Failed to switch profile" -t 2000
    fi
    index="$next"
fi

echo "${icons[$index]} ${labels[$index]}"
