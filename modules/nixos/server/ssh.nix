{ lib, ... }:
{
  # Re-enable SSH (core/hardening disables it) but keep it VPN-only.
  services.openssh = {
    enable = lib.mkForce true;
    openFirewall = false;

    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  # Admit SSH only on the VPN interface, never the WAN.
  networking.firewall.interfaces.wg0.allowedTCPPorts = [ 22 ];
}
