# Waybar custom/vpn on-click: bring the active WireGuard connection down, or
# bring the default one (wg0) up if none is active.
vpn_default="wg0"

active_vpn="$(nmcli -t -f NAME,TYPE,DEVICE connection show --active |
    awk -F: '$2 == "wireguard" { print $1 }')"

if [ -n "$active_vpn" ]; then
    nmcli connection down "$active_vpn"
else
    nmcli connection up "$vpn_default"
fi
