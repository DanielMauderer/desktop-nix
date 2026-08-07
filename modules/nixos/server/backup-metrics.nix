# Backup freshness, exported the same way nixos-metrics.nix exports update
# health: an hourly oneshot writing a `.prom` file that the node exporter's
# textfile collector re-serves on :9100. Read that module's header first — the
# atomic-rename and stale-file rules apply here identically.
#
# Exposure (no new WAN ports; the WAN surface stays UDP 51820 + TCP 80/443):
#   none. This module opens no socket.
#
# Why this is worth a module of its own. Three services on this box write a
# nightly backup onto the ZFS pool — `forgejo dump` (forgejo.nix), paperless'
# `document_exporter` (paperless.nix) and `pg_dumpall` (postgresql.nix) — and
# each of them is the *only* copy of that service's data that survives losing
# the SSD. The systemd collector already shows a backup unit that fails loudly.
# What it cannot show is the failure mode that actually loses data: a unit that
# exits 0 having written nothing, or a timer that quietly stopped firing, or a
# dump that has been shrinking for a week. Those are properties of the files on
# disk, not of the unit, so they have to be measured from the files.
#
# Deliberately *not* merged into nixos-metrics.nix. The two ask unrelated
# questions of unrelated subsystems, they can fail independently, and keeping
# them in separate `.prom` files means `node_textfile_mtime_seconds` — which is
# per file — stays a meaningful freshness signal for each.
{ pkgs, lib, ... }:
let
  # The shared contract with metrics.nix's textfile collector flag. Same
  # literal, same reason, as in nixos-metrics.nix.
  textfileDir = "/var/lib/node-exporter-textfile";

  # `job` label → directory holding that service's backups. Each of these is
  # owned by its own service and mode 0750 or 0700 (the pg dump holds every
  # role in the cluster), which is why the unit below runs as root: it is the
  # only thing on the box entitled to stat all three.
  #
  # Kept as literals rather than read out of `config.services.*`, matching how
  # metrics.nix holds its siblings' ports: a path that silently retargets
  # itself when another module moves is harder to reason about than one that
  # goes stale loudly — and "stale" here means the metric drops to 0, which the
  # dashboard shows as a missing backup.
  backupDirs = {
    forgejo = "/hdd_pool_1/services/forgejo/dump"; # forgejo.nix, tar.zst, 8w
    paperless = "/hdd_pool_1/services/paperless/export"; # paperless.nix
    postgresql = "/hdd_pool_1/services/postgresql/dump"; # postgresql.nix
  };

  path = lib.makeBinPath (
    with pkgs;
    [
      coreutils
      findutils
      gawk
    ]
  );

  probe = job: dir: ''
    # --- ${job} ---
    # `|| true` covers the directory not existing yet (a service enabled but
    # never yet backed up) and covers `head` closing the pipe under `pipefail`.
    # An empty result falls through to zeros, which is the correct reading:
    # "no backup", not "no data".
    newest=$(find ${dir} -maxdepth 1 -type f -printf '%T@ %s\n' 2>/dev/null \
      | sort -rn | head -n1 || true)
    if [ -n "$newest" ]; then
      # %T@ is fractional; Prometheus takes a float, but truncating keeps the
      # series readable and a backup is never timed to the microsecond.
      ts=''${newest%% *}
      ts=''${ts%%.*}
      size=''${newest##* }
    else
      ts=0
      size=0
    fi
    # Total bytes and file count describe the *retention* policy working:
    # forgejo keeps 8 weeks, postgresql keeps exactly current + .prev, so a
    # count that climbs without bound is a pruning bug filling the pool.
    # The `|| true` goes *inside* the first pipeline stage, not after the whole
    # pipeline. Written as `find … | awk … || echo 0`, a missing directory makes
    # find exit non-zero, so both awk's `0` and echo's `0` are captured — and the
    # sample line becomes two lines, which is a parse error that drops every
    # textfile sample in the scrape, not just this one.
    total=$( { find ${dir} -maxdepth 1 -type f -printf '%s\n' 2>/dev/null || true; } \
      | awk '{ s += $1 } END { print s + 0 }')
    files=$( { find ${dir} -maxdepth 1 -type f 2>/dev/null || true; } | wc -l)
    {
      echo "backup_last_success_timestamp_seconds{job=\"${job}\"} $ts"
      echo "backup_last_size_bytes{job=\"${job}\"} $size"
      echo "backup_total_size_bytes{job=\"${job}\"} $total"
      echo "backup_file_count{job=\"${job}\"} $files"
    } >> "$tmp"
  '';

  script = pkgs.writeShellScript "backup-metrics" ''
    set -euo pipefail
    export PATH=${path}

    out=${textfileDir}/backups.prom
    tmp="$out.tmp"

    {
      echo "# HELP backup_last_success_timestamp_seconds Modification time of the newest file in the backup directory."
      echo "# TYPE backup_last_success_timestamp_seconds gauge"
      echo "# HELP backup_last_size_bytes Size of the newest backup file."
      echo "# TYPE backup_last_size_bytes gauge"
      echo "# HELP backup_total_size_bytes Total bytes retained in the backup directory."
      echo "# TYPE backup_total_size_bytes gauge"
      echo "# HELP backup_file_count Files retained in the backup directory."
      echo "# TYPE backup_file_count gauge"
    } > "$tmp"

    ${lib.concatStringsSep "\n" (lib.mapAttrsToList probe backupDirs)}

    # Atomic swap — a partially written file is a parse error that drops every
    # sample in the scrape, not just these.
    mv "$tmp" "$out"
  '';
in
{
  systemd.services.backup-metrics = {
    description = "Collect backup freshness metrics for the node exporter";

    # The backup directories live on the ZFS pool, so reading them before
    # zfs-mount.service would stat the empty shadow tree under the unmounted
    # mountpoint and report every backup as missing — a false alarm, which is
    # worse than no alarm. Ordering only, never Requires: a pool that fails to
    # mount must not also silence the metric that would say so. It reports
    # zeros in that case, which is exactly right.
    after = [ "zfs-mount.service" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = script;
    };
  };

  systemd.timers.backup-metrics = {
    description = "Hourly refresh of the backup freshness metrics";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
      OnBootSec = "3min";
      RandomizedDelaySec = "5min";
    };
  };
}
