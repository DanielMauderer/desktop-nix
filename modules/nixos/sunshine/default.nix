# Sunshine — game-stream host for Moonlight clients (the TV), desktop only.
#
# Runs as a user service in the Hyprland session. capSysAdmin installs a
# cap_sys_admin wrapper so Sunshine can use KMS capture (lowest latency on the
# Vega; encoding goes through VAAPI). The module also enables uinput for
# Moonlight's virtual mouse/keyboard/gamepad, and Avahi so clients discover the
# host on the LAN.
#
# Ports are opened by hand instead of `openFirewall`: only to the home LAN, and
# without the web UI (TCP 47990) — configure and pair from the desktop itself at
# https://localhost:47990. No `settings` are set, so the UI keeps ownership of
# ~/.config/sunshine/sunshine.conf.
_: {
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
  };

  # IPv4 from the Fritz!Box subnet on the wired NIC only. Not `allowedTCPPorts`,
  # which opens every interface — the wg0/wg1 tunnels and the globally routed
  # IPv6 addresses included. Sunshine binds IPv4 only by default.
  #   TCP 47984 HTTPS (pairing), 47989 HTTP, 48010 RTSP
  #   UDP 47998 video, 47999 control, 48000 audio, 48002 mic, 48010 RTSP
  networking.firewall.extraInputRules = ''
    iifname "enp34s0" ip saddr 192.168.178.0/24 tcp dport { 47984, 47989, 48010 } accept
    iifname "enp34s0" ip saddr 192.168.178.0/24 udp dport { 47998-48000, 48002, 48010 } accept
  '';
}
