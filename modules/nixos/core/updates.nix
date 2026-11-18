# Daily pull-and-switch from the CI-gated `release` branch. No auto-reboot on
# the workstations, so kernel/initrd changes take effect on the next manual
# reboot. The home-server turns it on (modules/nixos/server/auto-reboot.nix).
# What actually moves the fleet forward is the scheduled CI lock bump, not autoUpgrade itself.
{ lib, ... }:
{
  system.autoUpgrade = {
    enable = true;
    flake = lib.mkDefault "github:DanielMauderer/desktop-nix/release";
    flags = [ "-L" ];
    dates = "daily";
    randomizedDelaySec = "45min";
    allowReboot = lib.mkDefault false;
  };
}
