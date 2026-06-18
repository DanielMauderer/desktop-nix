# Declarative disk layout for the home server's OS SSD (DECISIONS 049).
#
# Disko owns ONLY the install SSD: a 1 GiB EFI System Partition (systemd-boot,
# mounted at /boot per modules/nixos/core/boot.nix) and a plain ext4 root filling
# the rest. No LUKS — the server stays powered-on headless at home and must boot
# unattended (same physical-security trade-off as the desktop, DECISIONS 038).
# Swap is zram (hardware.nix), so there is no swap partition.
#
# The ZFS DATA pool is NOT touched here: it lives on a separate hardware-RAID LUN
# that pre-exists and is imported at runtime (modules/nixos/server/zfs.nix), so a
# reinstall reformats the OS SSD without endangering the data.
#
# This file is added to the host via flake.nix's mkHost module list (NOT imported
# by default.nix), so any nixosTest that imports default.nix boots off its own
# scratch disk.
#
# Install-time use (see hosts/home-server/INSTALL.md): format with
#   sudo nix --experimental-features "nix-command flakes" run \
#     github:nix-community/disko/latest -- --mode disko \
#     /tmp/cfg/hosts/home-server/disk.nix
{ inputs, ... }:
{
  imports = [ inputs.disko.nixosModules.disko ];

  disko.devices.disk.main = {
    type = "disk";
    # VERIFY with `lsblk` before formatting — the OS SSD, NOT the RAID LUN that
    # carries the ZFS pool. An NVMe SSD is usually /dev/nvme0n1; SATA is /dev/sda.
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
            # Lock down the ESP: only root can read it (it holds the
            # unencrypted kernel/initrd).
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
