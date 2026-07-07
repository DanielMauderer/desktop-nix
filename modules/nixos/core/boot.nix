_: {
  boot.loader = {
    systemd-boot = {
      enable = true;

      # Keep the last 20 generations in the boot menu as a known-good fallback
      # after a bad auto-upgrade.
      configurationLimit = 20;
    };

    efi.canTouchEfiVariables = true;
  };
}
