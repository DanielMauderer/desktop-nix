# Hardware enablement for the work laptop (Ticket 14). Same pattern as the
# pilot (hosts/private-laptop/hardware.nix): Intel iGPU assumption (iHD, Gen8+)
# that must be verified during the hardware-capture step in
# docs/runbooks/work-laptop.md. If the iGPU is pre-Broadwell swap to
# `intel-vaapi-driver` / `i965`. The machine-specific kernel-module probe
# produced by `nixos-generate-config --no-filesystems` is committed separately
# as hardware/hardware-configuration.nix at install time.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Sensible initrd baseline for a modern Intel NVMe laptop — re-confirm against
  # `nixos-generate-config --no-filesystems` at install, dropping duplicates.
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

    # Intel iGPU: hardware video acceleration (VAAPI/QSV). programs.hyprland
    # already enables hardware.graphics; this only adds the Intel VAAPI drivers.
    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        # iHD: Gen8+ (Broadwell and newer). For pre-Broadwell swap to
        # intel-vaapi-driver (i965) and set LIBVA_DRIVER_NAME = "i965".
        intel-media-driver
        # oneVPL runtime for QuickSync (replaces the old intel-media-sdk).
        vpl-gpu-rt
      ];
    };
  };
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  # Compressed RAM swap — no encrypted swap partition, no hibernation (accepted).
  zramSwap.enable = true;
}
