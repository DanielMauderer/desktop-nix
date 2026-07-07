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
      # Hardware-RAID HBA (megaraid_sas for LSI/MegaRAID, mpt3sas for SAS3008).
      "megaraid_sas"
      "mpt3sas"
    ];

    # CPU virtualisation: set "kvm-amd" or "kvm-intel" to match the box.
    # kernelModules = [ "kvm-amd" ];

    # LTS kernel: always within ZFS's supported range, unlike `latest`.
    kernelPackages = lib.mkDefault pkgs.linuxPackages;
  };

  # Required by ZFS; MUST be unique per machine. Regenerate with:
  #   head -c4 /dev/urandom | od -An -tx1 | tr -d ' \n'
  networking.hostId = "8f4c2a1b";

  # Both vendor lines are harmless; only the matching CPU's takes effect.
  hardware = {
    enableRedistributableFirmware = true;
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  };

  # zram swap, no swap partition.
  zramSwap.enable = true;
}
