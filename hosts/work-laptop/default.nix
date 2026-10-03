{ config, lib, ... }:
let
  # Flip after the host age key is enrolled and `sops updatekeys` has run on
  # secrets/work-laptop/*.yaml (INSTALL.md §2) — until then this box can't
  # decrypt them, and secret activation would fail.
  enrolled = false;
in
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

  # Work VPN (wg1) and personal secrets. Everything company-specific lives
  # inside the sops files, not in this repo's plaintext:
  # - secrets/work-laptop/vpn.yaml  `vpn-wg-conf`: the full wg-quick config
  #   (key, address, peer, MTU, keepalive) from the old NetworkManager `wg0`.
  # - secrets/work-laptop/user.yaml `ssh-id-ed25519` (passphrase-protected) and
  #   `npmrc` (the whole ~/.npmrc, registry tokens included).
  sops = lib.mkIf enrolled {
    secrets = {
      vpn-wg-conf.sopsFile = ../../secrets/work-laptop/vpn.yaml;
      ssh-id-ed25519 = {
        sopsFile = ../../secrets/work-laptop/user.yaml;
        owner = "maudi";
        path = "/home/maudi/.ssh/id_ed25519";
      };
      npmrc = {
        sopsFile = ../../secrets/work-laptop/user.yaml;
        owner = "maudi";
        path = "/home/maudi/.npmrc";
      };
    };
  };
  # Full IPv4 tunnel, on demand: `systemctl start wg-quick-wg1`. wg0 stays
  # reserved for the home-server client.
  networking.wg-quick.interfaces.wg1 = lib.mkIf enrolled {
    configFile = config.sops.secrets.vpn-wg-conf.path;
    autostart = false;
  };
  # sops-nix would otherwise create ~/.ssh root-owned for the key symlink.
  systemd.tmpfiles.rules = lib.mkIf enrolled [ "d /home/maudi/.ssh 0700 maudi users -" ];

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
}
