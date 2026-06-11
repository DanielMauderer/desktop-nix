# Stub — placeholder until hardware config and real modules land in Ticket 15.
# CachyOS kernel (chaotic-nyx) is wired in Ticket 11.
{ username, ... }:
{
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = [
      "defaults"
      "size=2G"
      "mode=755"
    ];
  };

  system.stateVersion = "25.05";
}
