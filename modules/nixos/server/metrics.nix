# Metrics half of the observability stack: native `services.prometheus` plus the
# exporters that describe this box's hardware. logs.nix is the matching half for
# the journal.
#
# The data path is entirely on loopback: Prometheus scrapes the exporters, and
# Grafana (grafana.nix) queries Prometheus. Nothing here is read from off the
# box, which is why every port below is bound to 127.0.0.1.
#
# Exposure (no new WAN ports; the WAN surface stays UDP 51820 + TCP 80/443):
#   9090  Prometheus itself — bound to 127.0.0.1 and never firewalled open at
#         all. Grafana runs on the same host and reaches it over loopback, so
#         there is nothing to admit; the TSDB is queried through Grafana's
#         Explore rather than Prometheus' own UI. Making it VPN-reachable is a
#         one-line change (drop `listenAddress`, add a wg0 rule), deliberately
#         not taken: the expression browser is an unauthenticated read of every
#         metric on the box.
#   9100  node exporter, scraped by Prometheus over loopback only.
#   9633  smartctl exporter, likewise.
#
# Because nothing here is listed in `allowedTCPPorts` (or admitted per-interface)
# the "WAN TCP surface is exactly 80/443" assertion in flake.nix is untouched.
#
# Storage: the TSDB stays on the SSD root at the module default
# /var/lib/prometheus2. This is not the free choice it looks like —
# `services.prometheus.stateDir` is a *name relative to /var/lib* (it becomes a
# systemd StateDirectory=), so unlike Loki and Grafana it cannot simply be
# pointed at the ZFS pool; that would need a bind mount. It is also the right
# place: samples are derived data that can be thrown away, which is the same
# argument forgejo.nix makes for keeping its state off the pool. Both a time and
# a size bound are set, and Prometheus trims on whichever trips first — but note
# the size bound governs the TSDB's own on-disk blocks, not free space on the
# filesystem as a whole. It is a cap on this service, not a guarantee about the
# root disk; the node exporter's `node_filesystem_*` series, scraped below, are
# what actually warn before the SSD runs out.
{ config, lib, ... }:
let
  prometheusPort = 9090;
  nodePort = 9100;
  smartctlPort = 9633;

  # Ports owned by the sibling modules. Kept as literals with this note rather
  # than read out of `config`, the same way forgejo.nix keeps the LAN/VPN subnets
  # in sync with nfs.nix — a scrape config that silently retargets itself when a
  # sibling module changes is harder to reason about than one that goes stale
  # loudly.
  lokiPort = 3100; # logs.nix
  alloyPort = 12345; # logs.nix
  grafanaPort = 3030; # grafana.nix

  # `job_name` is what shows up as the `job` label on every sample, so these
  # names end up in dashboards and alert expressions.
  localJob = name: port: {
    job_name = name;
    static_configs = [
      { targets = [ "127.0.0.1:${toString port}" ]; }
    ];
  };
in
{
  services.prometheus = {
    enable = true;
    port = prometheusPort;

    # Loopback only — see the exposure note above.
    listenAddress = "127.0.0.1";

    # Up to 90 days of history, and at most 20 GiB of TSDB blocks: Prometheus
    # applies both and deletes on whichever triggers earliest. The time bound is
    # the intent; the size bound is the backstop if a scraped target starts
    # emitting high-cardinality series. See the header note on what the size
    # bound does and does not promise about the root filesystem.
    retentionTime = "90d";
    extraFlags = [ "--storage.tsdb.retention.size=20GB" ];

    globalConfig = {
      scrape_interval = "30s";
      # Fail a scrape well before the next one starts, so a wedged target shows
      # up as `up == 0` instead of stacking overlapping requests.
      scrape_timeout = "10s";
    };

    exporters = {
      # Hardware and kernel metrics: CPU, memory, load, disk I/O, filesystems,
      # network, hwmon temperatures, and — the reason it matters on this box —
      # the `zfs` collector, which is enabled by default on Linux and exposes
      # ARC statistics and per-pool state for hdd_pool_1.
      node = {
        enable = true;
        listenAddress = "127.0.0.1";
        port = nodePort;
        # Both are off by default. `systemd` turns every unit's state into a
        # metric, which is how a failed forgejo/paperless/podman unit becomes
        # visible without reading the journal; `processes` gives run-queue and
        # process-state counts that the default `stat` collector does not.
        enabledCollectors = [
          "systemd"
          "processes"
        ];
      };

      # Drive health. The node exporter reports nothing about the *disks*
      # themselves — only the filesystems on top of them — so on a box whose
      # whole point is a 4-drive mirrored pool this is the exporter that
      # actually warns before a vdev degrades: reallocated sectors, pending
      # sectors, power-on hours, temperature, NVMe wear levelling.
      #
      # Runs as root by necessity (SMART needs raw device access); it is a
      # loopback-only reader with no write path.
      #
      # Caveat for this box: the pool sits behind the MegaRAID/SAS HBA named in
      # hosts/home-server/hardware.nix. `smartctl --scan` — which this exporter
      # runs when `devices` is empty — often sees only the controller's LUN
      # there, not the drives behind it, and the exporter exits when it finds
      # nothing. If `systemctl status prometheus-smartctl-exporter` is failed
      # after the first switch, enumerate them explicitly instead, using the
      # device syntax `smartctl --scan -d megaraid` reports, e.g.
      #   devices = [ "/dev/bus/0 -d megaraid,0" … ];
      # Nothing else in the stack depends on this exporter.
      smartctl = {
        enable = true;
        listenAddress = "127.0.0.1";
        port = smartctlPort;
      };
    };

    # The smartctl job is gated on the exporter actually being enabled:
    # smartctl_exporter exits when `smartctl --scan` finds nothing, which is the
    # situation in a VM with virtio disks. The nixosTest turns the exporter off,
    # and this keeps it from leaving a permanently-down scrape target behind.
    scrapeConfigs = [
      (localJob "node" nodePort)
      (localJob "prometheus" prometheusPort)
      (localJob "loki" lokiPort)
      (localJob "alloy" alloyPort)
      (localJob "grafana" grafanaPort)
    ]
    ++ lib.optional config.services.prometheus.exporters.smartctl.enable (
      localJob "smartctl" smartctlPort
    );
  };
}
