# Hardware enablement for the gaming + dev desktop (Ticket 15). The curated,
# known-good bits live here; the machine-specific kernel-module probe that
# `nixos-generate-config` produces is committed separately as
# hardware/hardware-configuration.nix at install time and imported from
# default.nix (the runbook covers generating it with --no-filesystems, since
# disko owns the filesystem layout — see disk.nix).
#
# AMD desktop counterpart to the laptops' Intel hardware.nix. The graphics
# stack (mesa/RADV + 32-bit) is owned by modules/nixos/gaming/gpu.nix and the
# CachyOS kernel by modules/nixos/gaming/kernel.nix, so neither is set here.
{
  config,
  lib,
  ...
}:
{
  boot = {
    # Sensible initrd baseline for a modern AMD desktop so the committed config
    # boots before the generated hardware-configuration.nix is added. Re-confirm
    # against `nixos-generate-config --no-filesystems` at install.
    initrd = {
      availableKernelModules = [
        "nvme"
        "ahci"
        "xhci_pci"
        "usbhid"
        "usb_storage"
        "sd_mod"
      ];
      # Load amdgpu in the initrd for early kernel mode-setting on the dGPU
      # (clean handoff to the Wayland session, no flicker).
      kernelModules = [ "amdgpu" ];
    };
    kernelModules = [ "kvm-amd" ];
  };

  hardware = {
    # Firmware (GPU/Wi-Fi/Bluetooth) + AMD CPU microcode.
    enableRedistributableFirmware = true;
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  };

  # AMD VAAPI driver (radeonsi) for hardware video decode in mpv/browsers —
  # the Intel laptops set iHD here instead.
  environment.sessionVariables.LIBVA_DRIVER_NAME = "radeonsi";

  # Compressed RAM swap. A gaming desktop usually has plenty of RAM, but zram
  # is a cheap, consistent fallback (matches the laptops). Hibernation is not
  # supported with zram-only swap (accepted).
  zramSwap.enable = true;
}
