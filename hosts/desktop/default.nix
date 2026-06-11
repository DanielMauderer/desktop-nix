_: {
  imports = [ ../../modules/nixos/base ];

  networking.hostName = "desktop";
  system.stateVersion = "25.05";

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
}
