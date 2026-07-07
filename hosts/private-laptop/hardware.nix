{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Initrd baseline for a modern Intel NVMe laptop so the committed config boots
  # before the generated hardware-configuration.nix is added.
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "nvme"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  hardware = {
    # Firmware (Wi-Fi/Bluetooth/GPU) + Intel CPU microcode.
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    # Intel iGPU VAAPI/QSV drivers (hardware.graphics is on via programs.hyprland).
    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        # iHD: Gen8+ (Broadwell+). Pre-Broadwell: intel-vaapi-driver + i965.
        intel-media-driver
        vpl-gpu-rt # oneVPL runtime for QuickSync
      ];
    };
  };
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  # zram swap instead of an encrypted swap partition (no hibernation).
  zramSwap.enable = true;
}
