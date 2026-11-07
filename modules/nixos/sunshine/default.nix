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
{ config, pkgs, ... }:
let
  # Prep command for apps.json: `match` switches DP-3 to the client's mode so
  # the stream is 1:1 instead of scaled, `restore` hands the layout back to
  # kanshi. Only modes DP-3 actually offers are applied; a bigger client (4K)
  # gets the native 1440p and Sunshine scales. `hyprctl eval`, not `keyword`:
  # Hyprland 0.56 is Lua-only (see the kanshi mirror in hosts/desktop).
  sunshine-display = pkgs.writeShellApplication {
    name = "sunshine-display";
    runtimeInputs = [
      config.programs.hyprland.package
      pkgs.jq
      pkgs.kanshi
    ];
    text = ''
      case "''${1:-}" in
        match)
          mode="''${SUNSHINE_CLIENT_WIDTH:?}x''${SUNSHINE_CLIENT_HEIGHT:?}@''${SUNSHINE_CLIENT_FPS:?}"
          if hyprctl monitors -j | jq -e --arg m "$mode" \
            '.[] | select(.name == "DP-3") | .availableModes | any(startswith($m + "."))' >/dev/null; then
            hyprctl eval "hl.monitor{output=\"DP-3\",mode=\"$mode\",position=\"0x0\",scale=1}"
          fi
          ;;
        restore) kanshictl reload ;;
        *)
          echo "usage: sunshine-display match|restore" >&2
          exit 2
          ;;
      esac
    '';
  };
in
{
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
  };

  environment.systemPackages = [ sunshine-display ];

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
