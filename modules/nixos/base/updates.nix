# Auto-update strategy (replaces rpm-ostreed staged auto-updates, DECISIONS 011):
# pull this flake's main branch on a daily timer and switch. No auto-reboot —
# kernel/initrd changes take effect on the next manual reboot.
#
# The cadence is `daily` (not `weekly`) to satisfy the Linux workstation security
# policy §4.4/§4.5: security updates must be applied within 72 hours. A daily
# pull keeps the worst-case window under that bound (DECISIONS 039). nixpkgs is
# nixos-unstable, so fixes land on `main` as soon as the flake lock is bumped.
_: {
  system.autoUpgrade = {
    enable = true;
    flake = "github:DanielMauderer/desktop-nix";
    flags = [ "-L" ];
    dates = "daily";
    randomizedDelaySec = "45min";
    allowReboot = false;
  };
}
