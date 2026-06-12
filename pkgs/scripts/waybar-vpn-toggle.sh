# Waybar custom/vpn on-click: bring the active WireGuard connection down, or
# bring the default one (wg0) up if none is active.
vpn_default="wg0"

active_vpn="$(nmcli -t -f NAME,TYPE,DEVICE connection show --active |
    awk -F: '$2 == "wireguard" { print $1 }')"

if [ -n "$active_vpn" ]; then
    if ! nmcli connection down "$active_vpn"; then
        echo "failed to bring down VPN '$active_vpn'" >&2
        exit 1
    fi
elif ! nmcli connection up "$vpn_default"; then
    echo "failed to bring up VPN '$vpn_default' (does the connection exist?)" >&2
    exit 1
fi
