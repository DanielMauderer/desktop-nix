# Bootloader: systemd-boot + EFI (matches all current machines).
# The disk layout (fileSystems) is host-specific and lives in hosts/<name>.
_: {
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
