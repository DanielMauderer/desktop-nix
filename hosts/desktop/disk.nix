# Declarative disk layout for the desktop (Ticket 15 / DECISIONS 038, revised).
#
# Same strategy as the laptops (DECISIONS 036/037): a 1 GiB EFI System Partition
# (systemd-boot, mounted at /boot per modules/nixos/core/boot.nix) and a LUKS2
# container filling the rest, holding the ext4 root. The original layout skipped
# LUKS to avoid a passphrase prompt on a headless-at-power-on gaming box; that
# trade-off was reversed — encryption at rest now outweighs the boot-time prompt,
# so every workstation is LUKS2 + ext4. Swap is zram (hardware.nix), so there is
# no encrypted swap partition to manage. The Steam library is re-downloaded onto
# this root (DECISIONS 038), so there is no separate data partition to mount.
#
# This file is added to the host only via lib/mkHost's module list in flake.nix
# (NOT imported by default.nix), so the nixosTest VMs — which import default.nix
# directly — never see the LUKS/ESP layout and boot off their own scratch disk.
#
# Install-time use (see hosts/desktop/INSTALL.md): format the disk with
#   sudo nix --experimental-features "nix-command flakes" run \
#     --inputs-from /tmp/cfg disko -- --mode disko \
#     /tmp/cfg/hosts/desktop/disk.nix
# disko then generates fileSystems."/" and "/boot" plus
# boot.initrd.luks.devices."cryptroot" for the running system.
_: {
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
        luks = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot";
            # TRIM through to the SSD. Mild metadata leak (which blocks are
            # unused) in exchange for SSD longevity — same call as the laptops.
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
