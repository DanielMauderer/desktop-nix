# Waybar custom/vpn text: show the active WireGuard connection name (if any).
vpn="$(nmcli -t -f NAME,TYPE connection show --active |
    awk -F: '$2 == "wireguard" { print $1 }')"

if [ -n "$vpn" ]; then
    echo " $vpn"
else
    echo " VPN"
fi
