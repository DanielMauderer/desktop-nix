# Bootloader: systemd-boot + EFI (matches all current machines).
# The disk layout (fileSystems) is host-specific and lives in hosts/<name>.
_: {
  boot.loader = {
    systemd-boot = {
      enable = true;

      # Bound the rollback set by *count*, not just by GC's 30-day window
      # (modules/nixos/core/nix.nix). Keep the last 20 generations in the boot
      # menu so there is always a known-good fallback to pick after a bad
      # auto-upgrade — the unattended-boot safety net for the desktop's
      # bleeding-edge CachyOS kernel in particular (audit ST-3/ST-4, DECISIONS 045).
      configurationLimit = 20;
    };

    efi.canTouchEfiVariables = true;
  };
}
