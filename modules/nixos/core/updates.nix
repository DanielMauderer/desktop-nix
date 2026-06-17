# Auto-update strategy (replaces rpm-ostreed staged auto-updates; DECISIONS 011,
# 039, 042): pull this flake on a daily timer and switch. No auto-reboot —
# kernel/initrd changes take effect on the next manual reboot.
#
# Per-host channel (DECISIONS 042): the default tracked ref is `main`
# (`mkDefault` below) — the private-laptop pilot and the desktop ride it. The
# work-laptop overrides `flake` to the `…/release` branch, which CI fast-forwards
# only after a commit's `build-hosts` job is green, so the policy machine never
# pulls a ref that failed to build. All hosts keep the same `daily` cadence.
#
# Cadence is `daily` (not `weekly`) for the Linux workstation security policy
# §4.4/§4.5 (security updates ≤ 72h; DECISIONS 039). `autoUpgrade` rebuilds from
# the committed `flake.lock`, so what actually moves the fleet forward is the
# scheduled CI job that runs `nix flake update` and auto-merges it on green
# (DECISIONS 043, .github/workflows/update-lock.yml) — not autoUpgrade itself.
{ lib, ... }:
{
  system.autoUpgrade = {
    enable = true;
    flake = lib.mkDefault "github:DanielMauderer/desktop-nix";
    flags = [ "-L" ];
    dates = "daily";
    randomizedDelaySec = "45min";
    allowReboot = false;
  };
}
