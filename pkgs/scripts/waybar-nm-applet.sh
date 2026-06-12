# Waybar network on-click-right: toggle the NetworkManager tray applet.
case "${1:-}" in
stop)
    killall nm-applet || true
    ;;
toggle)
    if pgrep -x nm-applet >/dev/null; then
        echo "Running"
        killall nm-applet || true
    else
        echo "Stopped"
        nm-applet --indicator &
    fi
    ;;
*)
    nm-applet --indicator &
    ;;
esac
