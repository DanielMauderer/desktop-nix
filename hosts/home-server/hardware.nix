# Hardware enablement for the home server. The curated, known-good bits live
# here; the machine-specific kernel-module probe from `nixos-generate-config
# --no-filesystems` is committed separately as hardware/hardware-configuration.nix
# at install time and imported from default.nix (disko owns the SSD layout — see
# disk.nix; the ZFS data pool sits on a hardware-RAID LUN and is imported by
# modules/nixos/server/zfs.nix).
{
  config,
  lib,
  pkgs,
  ...
}:
{
  boot = {
    initrd.availableKernelModules = [
      "nvme"
      "ahci"
      "xhci_pci"
      "usbhid"
      "usb_storage"
      "sd_mod"
      # Hardware-RAID HBA: confirm the right one against
      # `nixos-generate-config` (megaraid_sas for LSI/MegaRAID, mpt3sas for
      # SAS3008-class controllers).
      "megaraid_sas"
      "mpt3sas"
    ];

    # CPU virtualisation for the container/VM workloads. Set the module that
    # matches the box: "kvm-amd" or "kvm-intel" (confirm at install).
    # kernelModules = [ "kvm-amd" ];

    # Pin a stable LTS kernel. ZFS tracks releases behind the bleeding edge, and
    # `boot.kernelPackages = latest` can leave the pool unbuildable after an
    # update; the LTS line is always within ZFS's supported range. mkDefault so
    # a future need can override.
    kernelPackages = lib.mkDefault pkgs.linuxPackages;
  };

  # Required by ZFS (pool-ownership / multi-host import safety). MUST be unique
  # per machine — regenerate for a different host with:
  #   head -c4 /dev/urandom | od -An -tx1 | tr -d ' \n'
  networking.hostId = "8f4c2a1b";

  # Firmware (NIC/HBA) + CPU microcode. updateMicrocode picks the vendor from
  # the running CPU at build via the generated hardware-configuration.nix; both
  # vendor lines are harmless (only the matching one takes effect).
  hardware = {
    enableRedistributableFirmware = true;
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  };

  # Compressed RAM swap (matches the rest of the fleet; no swap partition).
  zramSwap.enable = true;
}
