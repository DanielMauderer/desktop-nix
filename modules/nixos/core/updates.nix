# Auto-update strategy (replaces rpm-ostreed staged auto-updates; DECISIONS 011,
# 039, 042): pull this flake on a daily timer and switch. No auto-reboot —
# kernel/initrd changes take effect on the next manual reboot.
#
# Build-gated channel (DECISIONS 042): every host tracks the CI-gated `release`
# branch (`mkDefault` below). CI fast-forwards `release` to a `main` commit only
# after that commit's full CI (flake-check + every per-host `build-hosts` job) is
# green (.github/workflows/promote-release.yml), so no machine ever auto-pulls a
# revision that failed to build — including one landed by a direct push to `main`
# that skipped the PR checks. All hosts keep the same `daily` cadence.
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
    flake = lib.mkDefault "github:DanielMauderer/desktop-nix/release";
    flags = [ "-L" ];
    dates = "daily";
    randomizedDelaySec = "45min";
    allowReboot = false;
  };
}
