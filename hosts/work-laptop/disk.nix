# 1 GiB ESP + LUKS2 container holding the ext4 root, same as the other
# workstations. Added to the host only via flake.nix's mkHost module list, not
# default.nix, so nixosTest VMs use their own scratch disk. Install: see INSTALL.md.
_: {
  disko.devices.disk.main = {
    type = "disk";
    # VERIFY with `lsblk` before formatting (NVMe is usually /dev/nvme0n1).
    device = "/dev/nvme0n1";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        luks = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot";
            settings.allowDiscards = true;
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}
