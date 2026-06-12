{ lib, ... }:
{
  imports = [
    ../../modules/nixos/base
    ../../modules/nixos/desktop
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

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
}
