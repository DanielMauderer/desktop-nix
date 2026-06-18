# Declarative disk layout for the pilot (Ticket 13 / DECISIONS 036).
#
# Full-disk NixOS over the wiped Silverblue install: a 1 GiB EFI System
# Partition (systemd-boot, mounted at /boot per modules/nixos/base/boot.nix)
# and a LUKS2 container filling the rest, holding the ext4 root. Swap is zram
# (hardware.nix), so there is no encrypted swap partition to manage.
#
# This file is added to the host only via lib/mkHost's module list in flake.nix
# (NOT imported by default.nix), so the nixosTest VMs — which import default.nix
# directly — never see the LUKS/ESP layout and boot off their own scratch disk.
#
# Install-time use (see hosts/private-laptop/INSTALL.md): format the disk with
#   sudo nix --experimental-features "nix-command flakes" run \
#     github:nix-community/disko/latest -- --mode disko \
#     /mnt-etc/nixos/hosts/private-laptop/disk.nix
# disko then generates fileSystems."/" and "/boot" plus
# boot.initrd.luks.devices."cryptroot" for the running system.
_: {
  disko.devices.disk.main = {
    type = "disk";
    # VERIFY with `lsblk` before formatting — NVMe laptops are usually
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
        luks = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot";
            # TRIM through to the SSD. Mild metadata leak (which blocks are
            # unused) in exchange for SSD longevity — acceptable on a laptop.
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
