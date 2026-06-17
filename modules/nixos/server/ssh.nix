# SSH — enabled, but reachable ONLY through the WireGuard VPN.
#
# `modules/nixos/core/hardening.nix` turns the SSH daemon off for the personal
# machines; the server is the one host that needs remote login, so re-enable it
# with `lib.mkForce` (overriding that plain `= false`). Crucially we do NOT open
# port 22 on the WAN: `openFirewall = false` keeps it out of the default
# accept-list, and the only firewall rule that admits :22 is scoped to the `wg0`
# interface (see below), so the daemon is unreachable from the public internet
# and answers exclusively to VPN peers.
{ lib, ... }:
{
  services.openssh = {
    enable = lib.mkForce true;

    # The firewall opening is interface-scoped (wg0 only), never the WAN.
    openFirewall = false;

    settings = {
      # Key-only, no root: the root account is already locked in core/hardening,
      # and admins log in as `maudi` (authorizedKeys set on the host).
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  # Admit SSH only on the VPN interface. `networking.firewall.interfaces.<if>`
  # matches by `iifname`, so this is robust to the server's WAN/LAN IP changing
  # and never exposes :22 outside the tunnel. Merges with the wg0 rules other
  # server modules add (e.g. the reverse-proxy admin UI).
  networking.firewall.interfaces.wg0.allowedTCPPorts = [ 22 ];
}
