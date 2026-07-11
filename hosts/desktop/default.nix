{ lib, ... }:
{
  imports = [
    ../../modules/nixos/base
    ../../modules/nixos/desktop
    ../../modules/nixos/gaming
    ../../modules/nixos/waydroid
    ../../modules/nixos/discord
    ../../modules/nixos/net
    ./hardware.nix
    ./hardware/hardware-configuration.nix
  ];

  networking.hostName = "desktop";
  system.stateVersion = "25.05";

  # Always at home, so the share mounts direct over the LAN (SSH still rides the
  # tunnel). `enable` stays off until enrollment.
  services.homeServerClient = {
    enable = true;
    address = "10.100.0.2/32";
    nfsHost = "192.168.178.96"; # home-server's LAN IP
    # Always-home + same LAN as the server: tunnel straight to its LAN IP so the
    # handshake doesn't depend on Fritz!Box NAT hairpin. Roaming hosts keep the
    # default vpn.mauderer.work:51820 (WAN) endpoint.
    endpoint = "192.168.178.96:51820";
  };

  # Dual-head desktop; mkBefore so it matches ahead of the laptop-internal fallback.
  home-manager.users.maudi.services.kanshi.settings = lib.mkBefore [
    {
      profile = {
        name = "desktop";
        outputs = [
          {
            criteria = "DP-3";
            mode = "2560x1440@144";
            position = "0,0";
          }
          {
            criteria = "DP-2";
            mode = "1920x1080@60";
            position = "2560,0";
          }
        ];
      };
    }
  ];

  # Pin workspaces 1-5 to DP-3 and 6-10 to DP-2 (single-output laptops share the
  # module but never set this, so they're unaffected).
  home-manager.users.maudi.wayland.windowManager.hyprland.settings.workspace = [
    "1, monitor:DP-3, default:true"
    "2, monitor:DP-3"
    "3, monitor:DP-3"
    "4, monitor:DP-3"
    "5, monitor:DP-3"
    "6, monitor:DP-2, default:true"
    "7, monitor:DP-2"
    "8, monitor:DP-2"
    "9, monitor:DP-2"
    "10, monitor:DP-2"
  ];
}
