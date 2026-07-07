# The graphics stack (gaming/gpu.nix) and CachyOS kernel (gaming/kernel.nix) are
# not set here.
{
  config,
  lib,
  ...
}:
{
  boot = {
    # Initrd baseline so the committed config boots before the generated
    # hardware-configuration.nix is added.
    initrd = {
      availableKernelModules = [
        "nvme"
        "ahci"
        "xhci_pci"
        "usbhid"
        "usb_storage"
        "sd_mod"
      ];
      # amdgpu in initrd for early KMS (clean handoff to Wayland, no flicker).
      kernelModules = [ "amdgpu" ];
    };
    kernelModules = [ "kvm-amd" ];
  };

  hardware = {
    enableRedistributableFirmware = true;
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  };

  environment.sessionVariables.LIBVA_DRIVER_NAME = "radeonsi";

  # zram swap instead of an encrypted swap partition (no hibernation).
  zramSwap.enable = true;
}
