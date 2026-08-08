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
#
#         This is also why the workstations do not write here directly. The
#         remote-write receiver enabled below shares this listener, so exposing
#         it to accept their pushes would expose the expression browser and the
#         admin API with it. Instead the wg0-facing ingest port lives on Alloy
#         (logs.nix), which forwards over loopback — one extra hop to keep the
#         paragraph above true. See modules/nixos/net/telemetry.nix.
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
  ntfyMetricsPort = 9686; # ntfy.nix — its dedicated loopback metrics listener
  postgresPort = 9187; # postgresql.nix — the exporter is declared next to the db

  # forgejo.nix. The one scrape target on this box that is not loopback-bound:
  # Forgejo serves /metrics from its main listener, which NPM proxies to the
  # WAN. It is therefore the one target that needs a credential — see the
  # forgejoJob note below.
  forgejoPort = 4000;

  # Written by nixos-metrics.nix, read by the node exporter's textfile
  # collector. Same convention as the ports above: a literal kept deliberately
  # in both places, with an assertion in flake.nix to make a divergence loud.
  textfileDir = "/var/lib/node-exporter-textfile";

  # `job_name` is what shows up as the `job` label on every sample, so these
  # names end up in dashboards and alert expressions.
  localJob = name: port: {
    job_name = name;
    static_configs = [
      { targets = [ "127.0.0.1:${toString port}" ]; }
    ];
  };

  # Forgejo's endpoint is token-gated (see forgejo.nix on why it has to be), so
  # its job cannot use the helper above. The token is handed to this unit as a
  # systemd credential, which systemd exposes at a path derived from the unit
  # name — deterministic, so it can be named here at build time even though the
  # file only exists at runtime.
  forgejoTokenCredential = "forgejo-metrics-token";
  forgejoJob = {
    job_name = "forgejo";
    static_configs = [
      { targets = [ "127.0.0.1:${toString forgejoPort}" ]; }
    ];
    authorization = {
      type = "Bearer";
      credentials_file = "/run/credentials/prometheus.service/${forgejoTokenCredential}";
    };
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
    extraFlags = [
      "--storage.tsdb.retention.size=20GB"

      # Accept `remote_write` pushes on /api/v1/write. This is what lets the
      # workstations appear here at all: they push rather than being scraped, so
      # that a laptop with a closed lid is an absent series instead of a firing
      # `hs-target-down` in alerts.nix. The flag opens no new socket — the
      # endpoint is on the listener above, which stays on loopback, and the only
      # thing that reaches it from off-box is Alloy's ingest hop in logs.nix.
      # Rationale in full: modules/nixos/net/telemetry.nix.
      "--web.enable-remote-write-receiver"
    ];

    # Downgraded from the full `promtool check config` to a parse-only run, and
    # only when the Forgejo job is in the config. The full check does not just
    # validate the YAML: it stats every file the config references, including
    # `authorization.credentials_file`. That file is a systemd credential which
    # by definition does not exist until the unit starts, so the full check
    # fails the *build* on a configuration that is correct at runtime.
    #
    # What is lost is small and bounded — file existence and a handful of
    # semantic checks — and the nixosTest gets it back where it actually
    # matters, by asserting every scrape target reports healthy on a running
    # instance. What would be lost by dropping the credential instead is the
    # token, and with it the only thing keeping Forgejo's /metrics off the WAN.
    checkConfig = lib.mkIf config.services.forgejo.enable "syntax-only";

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
        # All three are off by default. `systemd` turns every unit's state into
        # a metric, which is how a failed forgejo/paperless/podman unit becomes
        # visible without reading the journal; `processes` gives run-queue and
        # process-state counts that the default `stat` collector does not.
        #
        # `textfile` re-exports whatever `*.prom` files it finds in the
        # directory below, which is how nixos-metrics.nix gets its series in
        # without running a second HTTP server — see that module's header. The
        # collector also emits `node_textfile_mtime_seconds` per file for free,
        # which is the only thing that distinguishes fresh values from a writer
        # that died an hour ago.
        enabledCollectors = [
          "systemd"
          "processes"
          "textfile"
        ];

        # Kept in sync with `textfileDir` in nixos-metrics.nix by an assertion
        # in flake.nix: a typo here does not fail anything, it just makes the
        # collector report an empty directory forever.
        extraFlags = [ "--collector.textfile.directory=${textfileDir}" ];
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

      # The cluster's own view of itself: connection counts, transaction and
      # deadlock rates, database sizes. Gated on postgresql.nix being imported,
      # so this file stays usable on a node that takes only part of the stack.
      #
      # The interesting property is that this exporter needs no secret. Its
      # default `dataSourceName` reaches the cluster over the Unix socket as
      # `user=postgres`, and `runAsLocalSuperUser` runs the unit as the
      # `postgres` system user — so upstream's **peer** auth maps it onto the
      # superuser role with no password anywhere. That is postgresql.nix's own
      # argument for having no sops entry, applied to a second consumer, and it
      # is why enabling this does not weaken the socket-only posture: the
      # exporter connects exactly the way `psql` does. Superuser specifically,
      # because `pg_stat_*` shows a non-superuser only its own sessions.
      postgres = lib.mkIf config.services.postgresql.enable {
        enable = true;
        listenAddress = "127.0.0.1";
        port = postgresPort;
        runAsLocalSuperUser = true;
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
    )
    # Gated on the sibling modules the same way the smartctl job is gated on
    # its exporter, so this file stays usable on a node that imports only part
    # of the stack — which is exactly what the observability nixosTest does.
    ++ lib.optional config.services.ntfy-sh.enable (localJob "ntfy" ntfyMetricsPort)
    ++ lib.optional config.services.prometheus.exporters.postgres.enable (
      localJob "postgres" postgresPort
    )
    ++ lib.optional config.services.forgejo.enable forgejoJob;
  };

  # Prometheus reads the Forgejo token through a systemd credential rather than
  # opening /run/secrets itself. The unit runs with `PrivateUsers = true` and a
  # sandbox it does not control, so "make the sops file readable by the
  # prometheus user" is a property that upstream could change under us;
  # LoadCredential is resolved by PID 1 before any of that applies, and lands
  # the value at a path that is stable by construction. forgejo.nix takes the
  # same route to hand the token to Forgejo.
  systemd.services.prometheus = lib.mkIf config.services.forgejo.enable {
    serviceConfig.LoadCredential = [
      "${forgejoTokenCredential}:${config.sops.secrets.forgejo-metrics-token.path}"
    ];
  };
}
