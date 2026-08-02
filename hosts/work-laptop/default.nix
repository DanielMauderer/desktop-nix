{ lib, ... }:
{
  imports = [
    ../../modules/nixos/base
    ../../modules/nixos/desktop
    ../../modules/nixos/net
    ./hardware.nix
    # Uncomment after running `nixos-generate-config --no-filesystems` at install:
    # ./hardware/hardware-configuration.nix
  ];

  networking.hostName = "work-laptop";
  system.stateVersion = "25.05";

  # Second tunnel (wg1) from the provider wg.conf. Stays off longer than the
  # other hosts: &work_laptop in .sops.yaml is still a placeholder, so this box
  # can't decrypt a per-host secret until it's age-enrolled (INSTALL.md §2).
  services.vpnClient = {
    # enable = true;                     # ← flip on after age + sops enrollment
    address = [ "FILL-ME/32" ]; # Address =
    endpoint = "FILL-ME:51820"; # Endpoint =
    publicKey = "FILL-ME="; # PublicKey =
  };

  # Keep the 5-min lock but lengthen Noctalia's auto-suspend to 30 min here.
  home-manager.users.maudi.local.idleSuspendSeconds = 1800;

  # Docked-at-desk (dual external) or docked-at-home (internal + HDMI); mkBefore
  # so a docked profile matches before the generic laptop-internal fallback.
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
  # The block reads `config.sops.secrets…`, so also add `config` to the module
  # signature on line 1 when you uncomment it.
  # 1. Replace the placeholder host key in .sops.yaml:
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
