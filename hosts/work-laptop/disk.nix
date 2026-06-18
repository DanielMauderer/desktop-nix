# Declarative disk layout for the work laptop (Ticket 14 / DECISIONS 037).
#
# Same strategy as the pilot (hosts/private-laptop/disk.nix / DECISIONS 036):
# 1 GiB EFI System Partition + LUKS2 container filling the rest, holding the
# ext4 root. Swap is zram (hardware.nix), no separate encrypted swap partition.
#
# Disko scope: this file is added to the host only via lib/mkHost's module list
# in flake.nix (NOT imported by default.nix). The nixosTest nodes import
# default.nix alone, so QEMU VMs never see the LUKS/ESP layout. Disko owns
# `fileSystems`; `nixos-generate-config --no-filesystems` produces the rest.
#
# Install-time use (see hosts/work-laptop/INSTALL.md):
#   sudo nix --experimental-features "nix-command flakes" run \
#     github:nix-community/disko/latest -- --mode disko \
#     /mnt-etc/nixos/hosts/work-laptop/disk.nix
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
