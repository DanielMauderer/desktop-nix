# The OS SSD only: 1 GiB ESP + plain ext4 root. No LUKS — the server boots
# unattended headless (the one unencrypted-root machine). The ZFS data pool lives
# on a separate RAID LUN imported at runtime (server/zfs.nix). Added to the host
# via flake.nix's mkHost module list, not default.nix. Install: see INSTALL.md.
_: {
  disko.devices.disk.main = {
    type = "disk";
    # VERIFY with `lsblk` — the OS SSD, NOT the RAID LUN carrying the ZFS pool.
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
            # Root-only: the ESP holds the unencrypted kernel/initrd.
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
