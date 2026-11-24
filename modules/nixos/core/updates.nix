# Pull-and-switch from the CI-gated `release` branch, checked every 10 minutes.
# No auto-reboot on the workstations, so kernel/initrd changes take effect on
# the next manual reboot. The home-server turns it on
# (modules/nixos/server/auto-reboot.nix).
# What actually moves the fleet forward is the scheduled CI lock bump, not autoUpgrade itself.
#
# Why so often: `release` only moves after the nightly lock bump has passed CI,
# which finishes at an unpredictable time. A once-a-day timer that fires before
# the promotion lands misses that day's update entirely.
#
# Why it is cheap: a full run evaluates the whole system (tens of seconds of CPU,
# a GitHub tarball download thanks to `--refresh`). The gate below first asks
# GitHub for the head of `release` with one `git ls-remote` (a few hundred bytes,
# not counted against the API rate limit) and exits when that rev was already
# applied. So a real rebuild only happens when `release` actually moved — about
# once a day — and every other run costs one HTTPS round trip.
{ config, lib, ... }:
let
  cfg = config.system.autoUpgrade;

  # "github:Owner/repo/branch" → git remote + ref for the gate. Any other flake
  # URL (a local override, say) disables the gate and every run rebuilds.
  parsed = lib.match "github:([^/]+)/([^/]+)/([^/?]+)" (toString cfg.flake);
  remote = "https://github.com/${lib.elemAt parsed 0}/${lib.elemAt parsed 1}";
  ref = "refs/heads/${lib.elemAt parsed 2}";

  stateFile = "/var/lib/nixos-upgrade/applied-rev";
  rebootParts = "/{initrd,kernel,kernel-modules}";
in
{
  system.autoUpgrade = {
    enable = true;
    flake = lib.mkDefault "github:DanielMauderer/desktop-nix/release";
    flags = [ "-L" ];
    dates = "*:0/10";
    randomizedDelaySec = "1min";
    allowReboot = lib.mkDefault false;
  };

  systemd.services.nixos-upgrade = lib.mkIf (cfg.enable && parsed != null) {
    serviceConfig.StateDirectory = "nixos-upgrade";

    script = lib.mkMerge [
      (lib.mkBefore ''
        # --- Gate: skip the rebuild when `release` has not moved -------------
        if ! remote_rev="$(git ls-remote ${remote} ${ref} | cut -f1)" || [ -z "$remote_rev" ]; then
          # Offline laptop, GitHub hiccup: not a failure worth an alert. A
          # longer outage shows up as nixpkgs staleness (alerts.nix).
          echo "Could not reach ${remote}; skipping this check."
          exit 0
        fi
        applied_rev="$(cat ${stateFile} 2>/dev/null || true)"
        ${
          # A kernel staged outside the reboot window still needs a run inside
          # it to reboot, so don't skip a pending reboot once the window opens.
          lib.optionalString cfg.allowReboot ''
            if [ "$(readlink /run/booted-system${rebootParts})" != \
                 "$(readlink /nix/var/nix/profiles/system${rebootParts})" ]; then
              ${
                if cfg.rebootWindow == null then
                  "applied_rev=pending-reboot"
                else
                  let
                    inherit (cfg.rebootWindow) lower upper;
                    op = if lower < upper then "&&" else "||";
                  in
                  ''
                    now="$(date +%H:%M)"
                    if [[ "$now" > "${lower}" ]] ${op} [[ "$now" < "${upper}" ]]; then
                      applied_rev=pending-reboot
                    fi
                  ''
              }
            fi
          ''
        }
        if [ "$remote_rev" = "$applied_rev" ]; then
          echo "release is still at $remote_rev; nothing to do."
          exit 0
        fi
        echo "release moved to $remote_rev; upgrading."
      '')
      # Only reached when the rebuild succeeded (the unit runs with `set -e`),
      # so a failed build is retried on the next check.
      (lib.mkAfter ''
        echo "$remote_rev" > ${stateFile}
      '')
    ];
  };
}
