{ lib, ... }:
{
  imports = [
    ../../modules/nixos/base
    ../../modules/nixos/desktop
    ./hardware.nix
    # Uncomment after running `nixos-generate-config --no-filesystems` at install:
    # ./hardware/hardware-configuration.nix
  ];

  networking.hostName = "work-laptop";
  system.stateVersion = "25.05";

  # Host-specific kanshi profiles: docked at the desk (two external monitors,
  # internal panel off) or docked at home (internal + HDMI). Prepended
  # (mkBefore) so a docked profile matches before the generic laptop-internal
  # fallback; undocked falls through to that fallback.
  home-manager.users.maudi.services.kanshi.settings = lib.mkBefore [
    {
      profile = {
        name = "work-laptop-docked-dual";
        outputs = [
          {
            criteria = "eDP-1";
            status = "disable";
          }
          {
            criteria = "DP-5";
            position = "0,0";
          }
          {
            criteria = "DP-6";
            position = "2560,0";
          }
        ];
      };
    }
    {
      profile = {
        name = "work-laptop-docked-hdmi";
        outputs = [
          {
            criteria = "eDP-1";
            position = "0,0";
          }
          {
            criteria = "HDMI-A-1";
            position = "1920,0";
          }
        ];
      };
    }
  ];

  # --- WireGuard VPN (uncomment after enrolling secrets/work-laptop/wireguard.yaml) ---
  # 1. Replace age1PLACEHOLDERworklaptop… in .sops.yaml with the real host key:
  #      cat /etc/ssh/ssh_host_ed25519_key.pub | nix run nixpkgs#ssh-to-age
  # 2. sops edit secrets/work-laptop/wireguard.yaml  (paste the WireGuard private key)
  # 3. Fill in the peer block below and uncomment.
  # 4. sudo nixos-rebuild switch --flake ~/desktop-nix#work-laptop
  #
  # sops.secrets.wireguard-key = {
  #   sopsFile = ../../secrets/work-laptop/wireguard.yaml;
  # };
  # networking.wg-quick.interfaces.wg0 = {
  #   privateKeyFile = config.sops.secrets.wireguard-key.path;
  #   address = [ "10.x.x.x/32" ]; # fill in: work VPN assigned address
  #   dns    = [ "x.x.x.x" ];      # fill in: work VPN DNS
  #   peers  = [
  #     {
  #       publicKey          = "…";       # work VPN server public key
  #       endpoint           = "…:51820"; # work VPN server endpoint
  #       allowedIPs         = [ "0.0.0.0/0" ];
  #       persistentKeepalive = 25;
  #     }
  #   ];
  # };
}
