{ lib, ... }:
{
  imports = [
    ../../modules/nixos/base
    ../../modules/nixos/desktop
    ../../modules/nixos/gaming
    ../../modules/nixos/waydroid
    ../../modules/nixos/discord
<<<<<<< HEAD
=======
    # home-server VPN client: `ssh home-server` + the NFS share. Keys, the sops
    # secret (secrets/desktop/wireguard.yaml) and the server's public wiring are
    # all in place; only `enable` below is left — flip it on last, once the
    # server is installed and reachable (hosts/desktop/INSTALL.md).
>>>>>>> b931bdd (discord and homeserver strategy)
    ../../modules/nixos/net
    ./hardware.nix
    ./hardware/hardware-configuration.nix
  ];

  networking.hostName = "desktop";
  system.stateVersion = "25.05";

  # Always at home, so the share mounts direct over the LAN (SSH still rides the
  # tunnel). `enable` stays off until enrollment.
  services.homeServerClient = {
    # enable = true;                     # ← flip on last, once the server is up
    address = "10.100.0.2/32";
    nfsHost = "192.168.1.2"; # ← EDIT: the home-server's LAN IP
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
}
