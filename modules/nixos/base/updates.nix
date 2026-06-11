# Auto-update strategy (replaces rpm-ostreed staged auto-updates, DECISIONS 011):
# pull this flake's main branch on a weekly timer and switch. No auto-reboot —
# kernel/initrd changes take effect on the next manual reboot.
_: {
  system.autoUpgrade = {
    enable = true;
    flake = "github:DanielMauderer/desktop-nix";
    flags = [ "-L" ];
    dates = "weekly";
    randomizedDelaySec = "45min";
    allowReboot = false;
  };
}
