# Light telemetry shipper: pushes this host's metrics and warning-level journal
# into the home-server's observability stack over wg0. The receiving half is
# modules/nixos/server/{metrics,logs}.nix.
#
# `enable`-gated like home-server-client.nix, and useless without it: every
# address below is inside the VPN subnet, so a host with no tunnel would just
# retry forever. An assertion in flake.nix ties the two together.
#
# Why push (remote_write) and not a Prometheus scrape job on the server:
# alerts.nix already provisions `hs-target-down` on `up == 0`, wired to ntfy. A
# laptop added as a scrape target would page on every lid close, and the fix
# would be to weaken an alert that currently earns its keep. remote_write
# creates no `up` series at all, so an absent client is invisible rather than
# broken — which is the correct semantics for a machine that is off half the
# day. It also means no inbound port is opened on the client.
#
# Why one Alloy rather than node_exporter + Alloy: Alloy's
# `prometheus.exporter.unix` is the node exporter compiled in, scraped
# in-process with no HTTP listener and no second unit. The server runs a
# standalone `services.prometheus.exporters.node` because Prometheus is local
# there and pull is free; here the whole point is to keep the footprint to one
# supervised process.
#
# Cost, since "must not impact gaming or work" is the requirement: one Go
# process, a 60s scrape (the server uses 30s), and low-priority resource limits
# below. The enrolled hosts already run WireGuard with
# `persistentKeepalive = 25`, so this adds no new timer wakeup class and no new
# reason for the NIC to leave a low-power state.
{ config, lib, ... }:
let
  cfg = config.services.homeServerTelemetry;

  host = config.networking.hostName;

  # Collector set for `prometheus.exporter.unix`. Two traps, both silent:
  #
  #  - `set_collectors` *replaces* the exporter's defaults rather than adding to
  #    them, so anything a dashboard panel queries has to be named here. A
  #    missing collector is a blank panel, not an error.
  #  - the names are node_exporter's flag names, which are not always the
  #    obvious ones — `powersupplyclass`, not `power_supply_class`. `alloy
  #    validate` does not check them, since to it this is just a list of strings.
  #
  # dashboards/clients.json is the consumer; keep the two in step. The
  # nixosTest asserts one metric per collector for exactly this reason.
  collectors = [
    "cpu" # node_cpu_seconds_total
    "stat" # node_boot_time_seconds, context switches
    "meminfo" # node_memory_*
    "loadavg" # node_load1/5/15
    "filesystem" # node_filesystem_*
    "diskstats" # node_disk_*_bytes_total
    "netdev" # node_network_*_bytes_total
    "hwmon" # node_hwmon_temp_celsius — CPU/GPU package temps
    "thermal_zone" # node_thermal_zone_temp — the laptops' ACPI zones
    "pressure" # node_pressure_*_waiting_seconds_total (PSI)
    "systemd" # node_systemd_unit_state — failed units without reading logs
    "uname" # node_uname_info — carries the $host dashboard variable
    "time" # node_time_seconds
    "powersupplyclass" # node_power_supply_* — laptop battery and AC state
  ];

  # Journal priorities to ship. syslog severities 0-4 are emerg..warning; 5/6
  # (notice/info) are the bulk of a Hyprland or Steam session's output and are
  # exactly what we do not want to pay to store for 90 days.
  maxPriority = "[0-4]";

  alloyConfig = ''
    // The node exporter, in-process. No HTTP listener of its own.
    prometheus.exporter.unix "local" {
      set_collectors = [${lib.concatMapStringsSep ", " (c: "\"${c}\"") collectors}]
    }

    // Both labels are pinned to the hostname. `instance` would otherwise default
    // to the scrape target's address, which is the same loopback address on every
    // client — every host's series would interleave into one. `host` is what
    // dashboards/clients.json filters on, and matches the label logs.nix promotes
    // out of the journal, so a metric and a log line agree on the machine's name.
    discovery.relabel "local" {
      targets = prometheus.exporter.unix.local.targets

      rule {
        target_label = "instance"
        replacement  = "${host}"
      }

      rule {
        target_label = "host"
        replacement  = "${host}"
      }
    }

    prometheus.scrape "local" {
      targets    = discovery.relabel.local.output
      forward_to = [prometheus.remote_write.server.receiver]

      // `job` is deliberately NOT "node": that is the server's own job label,
      // and the panels in dashboards/host.json select on it. Keeping the names
      // distinct is what stops client series appearing in the server's graphs.
      job_name        = "client-node"
      scrape_interval = "${cfg.scrapeInterval}"

      // Stated rather than left at Alloy's 10s default, which is a footgun: the
      // component *refuses its whole config* when the timeout exceeds the
      // interval, and Alloy then restarts forever without ever shipping a
      // sample. So the two have to move together — see the option descriptions.
      scrape_timeout  = "${cfg.scrapeTimeout}"
    }

    prometheus.remote_write "server" {
      endpoint {
        url = "http://${cfg.serverHost}:${toString cfg.metricsPort}/api/v1/write"
      }

      // Bounded on purpose: a suspended laptop accumulates WAL, and Prometheus
      // rejects samples older than its head block (out-of-order window is 0 by
      // default). Replaying a day of WAL would produce a burst of 400s and still
      // store nothing. Capping the WAL turns that into a clean gap in the graph,
      // which is the honest rendering of "the machine was asleep".
      wal {
        truncate_frequency = "30m"
        max_keepalive_time = "1h"
      }
    }

    // Same promoted fields as the server's logs.nix — low cardinality only, so
    // Loki does not end up with one stream per PID — plus a priority filter.
    loki.relabel "journal" {
      // Required by the component even though the rules are consumed by
      // reference below rather than forwarded here.
      forward_to = []

      // Drop notice/info/debug before anything is forwarded. This has to live in
      // the journal relabel rules: `__journal_*` are internal labels that no
      // longer exist further down the pipeline. `matches` on the source cannot
      // express it — journal match syntax ANDs across fields and Alloy does not
      // support the OR form that `PRIORITY` <= 4 would need.
      rule {
        source_labels = ["__journal_priority"]
        regex         = "${maxPriority}"
        action        = "keep"
      }

      rule {
        source_labels = ["__journal__systemd_unit"]
        target_label  = "unit"
      }

      rule {
        source_labels = ["__journal__hostname"]
        target_label  = "host"
      }

      rule {
        source_labels = ["__journal_priority_keyword"]
        target_label  = "level"
      }

      rule {
        source_labels = ["__journal_syslog_identifier"]
        target_label  = "syslog_identifier"
      }
    }

    loki.source.journal "read" {
      forward_to    = [loki.write.server.receiver]
      relabel_rules = loki.relabel.journal.rules

      // Distinct from the server's "systemd-journal" for the same reason as the
      // scrape job above: dashboards/logs.json selects on it.
      labels = { job = "client-journal" }

      // One hour of backfill on a cold start. The server allows 12h; a client
      // that has been off for a week has nothing worth replaying, and this keeps
      // a resume from spending upload bandwidth on stale warnings.
      max_age = "${cfg.journalBackfill}"
    }

    loki.write "server" {
      endpoint {
        url = "http://${cfg.serverHost}:${toString cfg.lokiPort}/loki/api/v1/push"
      }

      // Unlike the metrics path there is no reason to drop these on an outage:
      // warnings are low volume and the whole point is to still have them after
      // the thing that caused them. Backed by the unit's StateDirectory.
      wal {
        enabled = true
      }
    }
  '';
in
{
  options.services.homeServerTelemetry = {
    enable = lib.mkEnableOption "pushing host metrics and warning-level logs to the home-server";

    serverHost = lib.mkOption {
      type = lib.types.str;
      default = "10.100.0.1";
      description = ''
        Address of the home-server's telemetry ingest. Defaults to its wg0
        address; overridden only by the nixosTest, which has no tunnel.
      '';
    };

    metricsPort = lib.mkOption {
      type = lib.types.port;
      default = 9099;
      description = ''
        Port of the server's Alloy `prometheus.receive_http` ingest. Kept in sync
        with modules/nixos/server/logs.nix by an assertion in flake.nix.
      '';
    };

    lokiPort = lib.mkOption {
      type = lib.types.port;
      default = 3100;
      description = "Port of the server's Loki push API (modules/nixos/server/logs.nix).";
    };

    scrapeInterval = lib.mkOption {
      type = lib.types.str;
      default = "60s";
      description = ''
        How often the in-process node exporter is scraped. Twice the server's 30s
        — a workstation's graphs do not need finer resolution than that, and the
        interval is the main lever on both CPU cost and upload volume.

        Must stay greater than {option}`scrapeTimeout`: Alloy rejects the whole
        config otherwise and restarts in a loop, shipping nothing.
      '';
    };

    scrapeTimeout = lib.mkOption {
      type = lib.types.str;
      default = "10s";
      description = ''
        How long a scrape may take before it is abandoned — the server's global
        value, and for the same reason: fail well before the next scrape starts
        rather than stacking overlapping reads of /proc and /sys.

        Must stay *below* {option}`scrapeInterval`. Lowering the interval without
        lowering this is the one way to misconfigure this module into a crash
        loop, which is why both are stated in the rendered config instead of
        relying on Alloy's default.
      '';
    };

    journalBackfill = lib.mkOption {
      type = lib.types.str;
      default = "1h";
      description = "How far back the journal reader goes on a cold start.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.alloy = {
      enable = true;
      # Stated rather than relying on the module default, since the config file
      # written below has to land where the unit looks for it. Alloy loads every
      # *.alloy file in this directory. Same idiom as server/logs.nix.
      configPath = "/etc/alloy";
    };

    environment.etc."alloy/config.alloy".text = alloyConfig;

    systemd.services.alloy = {
      # Ordering only, never a Requires: the tunnel comes and goes on a roaming
      # host, and Alloy is built to retry with backoff. Refusing to start without
      # wg0 would mean no local buffering exactly when it is needed.
      after = [ "wg-quick-wg0.service" ];

      # The point of "light". `CPUWeight`/`IOWeight` matter only under
      # contention, which is the only time this process could be noticed — and
      # deliberately not `CPUQuota`, which would throttle the agent even on an
      # idle machine and make it fall behind precisely during a load spike worth
      # recording. `MemoryHigh` reclaims before `MemoryMax` kills, so a WAL
      # growing during a long outage gets throttled rather than OOM-killed.
      #
      # Journal access needs no `SupplementaryGroups` here: Alloy runs under
      # DynamicUser and the upstream NixOS module already grants
      # `systemd-journal` for exactly this use.
      serviceConfig = {
        Nice = 10;
        CPUWeight = 20;
        IOWeight = 20;
        MemoryHigh = "200M";
        MemoryMax = "384M";
      };
    };
  };
}
