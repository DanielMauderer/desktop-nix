# The half of the observability stack that watches *this repo* rather than the
# hardware: whether the nightly update pipeline is still working.
#
# The box updates itself. `modules/nixos/core/updates.nix` runs
# `system.autoUpgrade` daily against `github:DanielMauderer/desktop-nix/release`
# with `allowReboot = false`, and .github/workflows/update-lock.yml bumps
# flake.lock nightly through an auto-merging PR. Both of those can stop working
# without anything going red: a failed `nixos-upgrade.service` is one journal
# line, a lock-bump workflow that lost its PAT just stops opening PRs, and a
# kernel update with `allowReboot = false` sits there until somebody notices.
# None of that is visible in metrics.nix's exporters, because none of it is a
# property of the hardware.
#
# Exposure (no new WAN ports; the WAN surface stays UDP 51820 + TCP 80/443):
#   none. This module opens no socket at all. It writes a text file, and the
#   node exporter — already loopback-only, see metrics.nix — serves it on :9100
#   alongside everything else.
#
# That indirection is the node exporter's *textfile collector*: it reads every
# `*.prom` file in one directory and re-exports the samples as if it had
# collected them itself. It is the standard way to get "the output of a script"
# into Prometheus without running a second HTTP server, and it means these
# series carry the same `job="node"` label as the rest of the box.
#
# Two rules the collector imposes on the writer, both handled below:
#
#   * the file must be written atomically. The collector may read at any moment,
#     and it parses whatever is there — a half-written file is a parse error and
#     poisons the *whole* scrape, not just this collector. Hence write-to-.tmp
#     then rename, which is atomic within a filesystem.
#   * a stale file is served forever. Nothing expires it, so if this unit dies
#     the last values keep being reported as current. `node_textfile_mtime_seconds`
#     (emitted by the collector itself, for free) is the guard, and the dashboard
#     alerts on it rather than trusting the values blindly.
#
# Timestamps are emitted as absolute Unix epochs, never as pre-computed ages.
# An age baked in at write time is already wrong by the time it is scraped;
# `time() - metric` in the query is correct at read time.
{ pkgs, lib, ... }:
let
  # Read by the node exporter's textfile collector — the flag naming this
  # directory is in metrics.nix, and an assertion in flake.nix keeps the two in
  # sync. On the SSD root, not the ZFS pool: this is derived data regenerated
  # hourly, the same argument metrics.nix makes for the TSDB.
  textfileDir = "/var/lib/node-exporter-textfile";

  # The system profile. Its generation links are the actual record of what this
  # box has switched to and when — `nix-env --list-generations` reads exactly
  # these, and reading them directly avoids needing the nix daemon in a unit
  # that runs hourly.
  systemProfile = "/nix/var/nix/profiles";

  # The parts of a system closure that a `switch` cannot swap out under a
  # running kernel. Comparing whole toplevel store paths is the obvious
  # implementation and the wrong one — those differ after *every* rebuild, so
  # the metric would read "reboot required" permanently. These three are what
  # nixos-rebuild's own boot-comparison looks at.
  rebootRelevant = [
    "initrd"
    "kernel"
    "kernel-modules"
  ];

  # Units whose last *completion* matters and which the systemd collector cannot
  # describe. That collector reports current state, which for a healthy oneshot
  # is `inactive` — indistinguishable from "never ran". The failure case is
  # covered there (`node_systemd_unit_state{state="failed"}`); "when did this
  # last succeed" is not, and for a nightly job that is the question.
  watchedUnits = [
    "nixos-upgrade.service"
    "nix-gc.service"
    "nix-optimise.service"
  ];

  path = lib.makeBinPath (
    with pkgs;
    [
      coreutils
      gnugrep
      gnused
      systemd
    ]
  );

  script = pkgs.writeShellScript "nixos-metrics" ''
    set -euo pipefail
    export PATH=${path}

    out=${textfileDir}/nixos.prom
    tmp="$out.tmp"
    : > "$tmp"

    # --- Pending reboot ---------------------------------------------------
    # 1 when the booted kernel/initrd is not the one the current generation
    # would boot. `allowReboot = false` in updates.nix means nothing clears
    # this on its own; it is a prompt for a human.
    reboot=0
    for component in ${lib.escapeShellArgs rebootRelevant}; do
      booted=$(readlink -f "/run/booted-system/$component" 2>/dev/null || echo missing-booted)
      current=$(readlink -f "/run/current-system/$component" 2>/dev/null || echo missing-current)
      if [ "$booted" != "$current" ]; then
        reboot=1
      fi
    done
    {
      echo "# HELP nixos_reboot_required Booted kernel/initrd differs from the current system generation."
      echo "# TYPE nixos_reboot_required gauge"
      echo "nixos_reboot_required $reboot"
    } >> "$tmp"

    # --- Generations ------------------------------------------------------
    # The generation links are symlinks, and GNU stat does not dereference by
    # default — so this is the link's own mtime, i.e. when the generation was
    # created. Dereferencing would give the store path's mtime, which Nix
    # normalises to epoch 1 for reproducibility and which is therefore useless.
    current_link=$(readlink -f ${systemProfile}/system || true)
    generation=0
    built=0
    for link in ${systemProfile}/system-*-link; do
      [ -e "$link" ] || continue
      if [ "$(readlink -f "$link")" = "$current_link" ]; then
        generation=$(echo "$link" | sed -e 's|.*/system-||' -e 's|-link$||')
        built=$(stat -c %Y "$link")
      fi
    done
    # `|| true` inside the substitution, not after the pipe: `pipefail` is on,
    # and on a machine with no system profile at all (which is every nixos-test
    # VM — the closure is booted directly, never installed into the profile)
    # `ls` exits non-zero and would abort the whole run under `set -e`.
    count=$( (ls -d ${systemProfile}/system-*-link 2>/dev/null || true) | wc -l)
    {
      echo "# HELP nixos_current_generation Number of the system generation currently activated."
      echo "# TYPE nixos_current_generation gauge"
      echo "nixos_current_generation $generation"
      echo "# HELP nixos_generation_count System generations retained in the profile."
      echo "# TYPE nixos_generation_count gauge"
      echo "nixos_generation_count $count"
      echo "# HELP nixos_generation_build_timestamp_seconds Creation time of the current system generation."
      echo "# TYPE nixos_generation_build_timestamp_seconds gauge"
      echo "nixos_generation_build_timestamp_seconds $built"
    } >> "$tmp"

    # --- How old is the flake lock ---------------------------------------
    # flake.lock itself is not on the box — the closure does not carry it. But
    # the nixpkgs version string does: `nixos-version` prints
    # <release>.<YYYYMMDD>.<rev>, where the date is nixpkgs' own lastModified.
    # That is precisely what update-lock.yml bumps, so a date that stops moving
    # means the workflow (or the daily autoUpgrade consuming it) has stalled.
    nixpkgs_date=0
    if [ -r /run/current-system/nixos-version ]; then
      day=$(sed -n 's/^[0-9.]*\.\([0-9]\{8\}\)\..*$/\1/p' /run/current-system/nixos-version)
      if [ -n "$day" ]; then
        nixpkgs_date=$(date -u -d "$day" +%s)
      fi
    fi
    {
      echo "# HELP nixos_nixpkgs_timestamp_seconds Commit date of the nixpkgs the running system was built from."
      echo "# TYPE nixos_nixpkgs_timestamp_seconds gauge"
      echo "nixos_nixpkgs_timestamp_seconds $nixpkgs_date"
    } >> "$tmp"

    # --- Store ------------------------------------------------------------
    # A path count, not a byte count: `du` over /nix/store is minutes of I/O and
    # this runs hourly. The bytes are already covered — node_filesystem_* on the
    # root filesystem is what actually warns before the SSD fills. This series
    # answers a different question: whether GC is keeping up.
    store_paths=$( (ls -U /nix/store 2>/dev/null || true) | wc -l)
    {
      echo "# HELP nixos_store_path_count Entries in /nix/store."
      echo "# TYPE nixos_store_path_count gauge"
      echo "nixos_store_path_count $store_paths"
    } >> "$tmp"

    # --- Last completion of the nightly units -----------------------------
    # systemd keeps these across restarts of the unit but not across reboots,
    # so a 0 here after a reboot means "not since boot", not "never".
    {
      echo "# HELP nixos_unit_last_finish_timestamp_seconds Last time the unit finished running."
      echo "# TYPE nixos_unit_last_finish_timestamp_seconds gauge"
      echo "# HELP nixos_unit_last_exit_code Exit status of the unit's last run."
      echo "# TYPE nixos_unit_last_exit_code gauge"
    } >> "$tmp"
    for unit in ${lib.escapeShellArgs watchedUnits}; do
      # Both properties are empty for a unit that does not exist on this host
      # (nix-optimise is conditional, and the observability test node has no
      # nixos-upgrade at all), which falls through to 0.
      finished=$(systemctl show "$unit" --property=ExecMainExitTimestamp --value 2>/dev/null || true)
      if [ -n "$finished" ]; then
        finished=$(date -d "$finished" +%s 2>/dev/null || echo 0)
      else
        finished=0
      fi
      status=$(systemctl show "$unit" --property=ExecMainStatus --value 2>/dev/null || true)
      [ -n "$status" ] || status=0
      echo "nixos_unit_last_finish_timestamp_seconds{unit=\"$unit\"} $finished" >> "$tmp"
      echo "nixos_unit_last_exit_code{unit=\"$unit\"} $status" >> "$tmp"
    done

    # Atomic swap — see the header note on why a partial file is worse than a
    # stale one.
    mv "$tmp" "$out"
  '';
in
{
  systemd = {
    # 0755, not 0700: the node exporter runs under upstream's DynamicUser and
    # has to traverse and read this. Nothing secret is written here — it is the
    # same data the exporter then serves unauthenticated on loopback.
    tmpfiles.rules = [
      "d ${textfileDir} 0755 root root -"
    ];

    services.nixos-metrics = {
      description = "Collect NixOS update and generation metrics for the node exporter";

      # Root, and deliberately not hardened into a sandbox: the whole job is to
      # read /nix/var/nix/profiles, /run/{booted,current}-system and the systemd
      # bus. It writes exactly one file and opens no network.
      serviceConfig = {
        Type = "oneshot";
        ExecStart = script;
      };
    };

    timers.nixos-metrics = {
      description = "Hourly refresh of the NixOS update metrics";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "hourly";
        # None of these values change fast, but all of them are wrong for as
        # long as the file is stale — so catch up after downtime rather than
        # waiting for the next whole hour.
        Persistent = true;
        # Also run shortly after boot, since a reboot is exactly the event that
        # flips nixos_reboot_required back to 0.
        OnBootSec = "2min";
        RandomizedDelaySec = "5min";
      };
    };
  };
}
