{ lib, pkgs, ... }:
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

  # Update channel (DECISIONS 042): the work laptop is the one HA / policy-bound
  # machine, so it tracks the CI-gated `release` branch instead of `main`. A
  # commit only reaches `release` after its `build-hosts` job is green
  # (.github/workflows/promote-release.yml), so an upgrade here is never the
  # first build of that revision. Pilot (private-laptop) + desktop stay on `main`;
  # the daily cadence is unchanged (modules/nixos/base/updates.nix).
  system.autoUpgrade.flake = "github:DanielMauderer/desktop-nix/release";

  # Idle policy (DECISIONS 042): keep the 5-min screen lock (modules/home/desktop/
  # lockscreen.nix) but lengthen auto-suspend from 10 → 30 min on this host, so an
  # unattended build/update or a long meeting on the dock isn't force-suspended.
  home-manager.users.maudi.services.swayidle.timeouts = lib.mkForce [
    {
      timeout = 300;
      command = "${pkgs.swaylock-effects}/bin/swaylock";
    }
    {
      timeout = 1800;
      command = "systemctl suspend";
    }
  ];

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
  # NOTE: the block below reads `config.sops.secrets…`, so when you uncomment it,
  # add `config` to this module's signature on line 1
  # (`{ lib, pkgs, ... }:` → `{ lib, pkgs, config, ... }:`); otherwise eval fails
  # with "config not in scope" (audit S-5).
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
