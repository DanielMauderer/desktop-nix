# Declarative disk layout for the desktop (Ticket 15 / DECISIONS 038).
#
# Full-disk NixOS over the wiped Silverblue install. Unlike the laptops
# (DECISIONS 036/037), the desktop is NOT LUKS-encrypted: it stays at home, a
# different physical-security profile, and skipping LUKS avoids a passphrase
# prompt at every boot on a headless-at-power-on gaming box. Layout: a 1 GiB EFI
# System Partition (systemd-boot, mounted at /boot per modules/nixos/base/boot.nix)
# and a plain ext4 root filling the rest. Swap is zram (hardware.nix), so there
# is no swap partition. The Steam library is re-downloaded onto this root
# (DECISIONS 038), so there is no separate data partition to mount.
#
# This file is added to the host only via lib/mkHost's module list in flake.nix
# (NOT imported by default.nix), so the nixosTest VMs — which import default.nix
# directly — never see this layout and boot off their own scratch disk.
#
# Install-time use (see docs/runbooks/desktop.md): format the disk with
#   sudo nix --experimental-features "nix-command flakes" run \
#     github:nix-community/disko/latest -- --mode disko \
#     /tmp/cfg/hosts/desktop/disk.nix
# disko then generates fileSystems."/" and "/boot" for the running system.
{ inputs, ... }:
{
  imports = [ inputs.disko.nixosModules.disko ];

  disko.devices.disk.main = {
    type = "disk";
    # VERIFY with `lsblk` before formatting — an NVMe SSD is usually
    # /dev/nvme0n1; a SATA SSD would be /dev/sda.
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
