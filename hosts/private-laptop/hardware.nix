# Hardware enablement for the pilot laptop (Ticket 13). The curated, known-good
# bits live here; the machine-specific kernel-module probe that
# `nixos-generate-config` produces is committed separately as
# hardware/hardware-configuration.nix at install time and imported from
# default.nix (the runbook covers generating it with --no-filesystems, since
# disko owns the filesystem layout — see disk.nix).
{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Sensible initrd baseline for a modern Intel NVMe laptop so the committed
  # config boots before the generated hardware-configuration.nix is added.
  # Re-confirm against `nixos-generate-config --no-filesystems` at install.
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

    # Intel iGPU: hardware video acceleration (VAAPI/QSV) for media playback —
    # the pilot's primary role. programs.hyprland already turns on
    # hardware.graphics; this only adds the Intel VAAPI drivers.
    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        # iHD: Gen8+ (Broadwell and newer). For pre-Broadwell hardware swap to
        # intel-vaapi-driver (i965) and set LIBVA_DRIVER_NAME = "i965".
        intel-media-driver
        # oneVPL runtime for QuickSync (replaces the old intel-media-sdk).
        vpl-gpu-rt
      ];
    };
  };
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  # Compressed RAM swap instead of an encrypted swap partition: keeps disk.nix
  # simple (no separate cryptswap) and is the right default for a media/light-dev
  # laptop. Hibernation is not supported with zram-only swap (accepted).
  zramSwap.enable = true;
}
