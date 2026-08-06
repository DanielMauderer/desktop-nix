# Metrics half of the observability stack: native `services.prometheus` plus the
# exporters that describe this box. logs.nix is the matching half for the
# journal.
#
# The data path is almost entirely on loopback: Prometheus scrapes the
# exporters, and Grafana (grafana.nix) queries Prometheus. Every port below is
# bound to 127.0.0.1. The one exporter that looks *outward* is blackbox, which
# makes outbound requests to the public hostnames — it still listens on
# loopback; only its probes leave the box.
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
#   9187  postgres exporter, likewise.
#   9115  blackbox exporter, likewise.
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
{
  config,
  lib,
  pkgs,
  ...
}:
let
  prometheusPort = 9090;
  nodePort = 9100;
  smartctlPort = 9633;
  postgresPort = 9187;
  blackboxPort = 9115;

  # Ports owned by the sibling modules. Kept as literals with this note rather
  # than read out of `config`, the same way forgejo.nix keeps the LAN/VPN subnets
  # in sync with nfs.nix — a scrape config that silently retargets itself when a
  # sibling module changes is harder to reason about than one that goes stale
  # loudly.
  lokiPort = 3100; # logs.nix
  alloyPort = 12345; # logs.nix
  grafanaPort = 3030; # grafana.nix

  # The hostnames blackbox probes, over the *public* path on purpose: DNS, the
  # Cloudflare edge, NPM's TLS termination and the backend, collapsed into one
  # `probe_success`. A loopback health check would stay green through a dead
  # AAAA record or an expired certificate, which are the two failures this box
  # is actually prone to.
  #
  # Keep in sync with the proxy hosts configured in the NPM UI
  # (reverse-proxy.nix) — a hostname removed there becomes a permanently failing
  # probe here.
  probeTargets = [
    "https://git.mauderer.work"
    "https://ntfy.mauderer.work"
  ];

  # `services.prometheus.exporters.blackbox.enableConfigCheck` (on by default)
  # runs `blackbox_exporter --config.check` over this at *build* time, so a typo
  # fails the build rather than silently producing a probe that never succeeds.
  blackboxConfig = (pkgs.formats.yaml { }).generate "blackbox.yml" {
    modules.http_2xx = {
      prober = "http";
      # Must stay below `globalConfig.scrape_timeout` (10s) below: the probe
      # runs *inside* the scrape, so a module timeout at or above it turns a
      # single dead target into a failed scrape of the whole exporter, and the
      # other target's result is lost with it.
      timeout = "5s";
      http = {
        method = "GET";
        # Both hostnames are HTTPS-only through NPM; a plain-HTTP answer means
        # something has gone wrong upstream even if it returns 200.
        fail_if_not_ssl = true;
        valid_http_versions = [
          "HTTP/1.1"
          "HTTP/2.0"
        ];
        # The zone publishes AAAA only (cloudflare-ddns.nix), but Cloudflare
        # serves both, and the box's own outbound path is the more reliable of
        # the two. Fall back rather than fail if one family is unavailable.
        preferred_ip_protocol = "ip4";
        ip_protocol_fallback = true;
      };
    };
  };

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

      # The shared cluster from postgresql.nix. Notable for what it does *not*
      # need: no password, no sops secret, and no TCP listener — the exporter
      # runs as the `postgres` system user (`runAsLocalSuperUser`, which also
      # pins DynamicUser off and adds AF_UNIX back to RestrictAddressFamilies)
      # and connects over /run/postgresql, where peer auth maps it onto the
      # `postgres` role. That is the same "a role is reachable only by the
      # system user of the same name" property postgresql.nix is built around.
      #
      # `dataSourceName` is left at the module default, which is already
      # `user=postgres database=postgres host=/run/postgresql sslmode=disable`.
      # Stated here only as a warning: rewriting it as a `postgresql://` URI
      # reintroduces a password and a TCP connection, and postgresql.nix forces
      # `listen_addresses = ""` precisely so that cannot work by accident.
      #
      # The cluster ships empty, so today this is mostly `pg_up` plus the
      # built-in `postgres` database. It becomes interesting the moment a
      # service takes a database, and costs nothing until then.
      postgres = {
        enable = true;
        listenAddress = "127.0.0.1";
        port = postgresPort;
        runAsLocalSuperUser = true;
      };

      # External uptime — the only exporter here that describes the *outside*
      # view of this box rather than its internals. It fetches the public
      # hostnames listed in `probeTargets`, so it goes red when DNS,
      # cloudflare-ddns, the Cloudflare edge, NPM or the backend fails, none of
      # which a local unit-state check can see.
      #
      # It listens on loopback like the rest; it is only its *probes* that
      # leave the box, as ordinary outbound HTTPS. `CAP_NET_RAW` comes from the
      # upstream unit (for ICMP probers) and is unused by the http_2xx module
      # configured above.
      blackbox = {
        enable = true;
        listenAddress = "127.0.0.1";
        port = blackboxPort;
        configFile = blackboxConfig;
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
      (localJob "postgres" postgresPort)
    ]
    ++ lib.optional config.services.prometheus.exporters.smartctl.enable (
      localJob "smartctl" smartctlPort
    )
    # Gated the same way as smartctl, and for the same reason: the VM test node
    # has no outbound network, so it turns the exporter off and this drops the
    # job with it rather than leaving a permanently-down target behind.
    ++ lib.optional config.services.prometheus.exporters.blackbox.enable {
      # The one job here that is not the `localJob` shape. Blackbox does not
      # expose the probe results at /metrics: it performs a probe per request,
      # with the URL under test passed as ?target=. So `targets` below is a list
      # of *URLs*, not host:port, and the three relabel rules put everything
      # back where Prometheus expects it:
      #
      #   1. the URL (which Prometheus put in `__address__`) becomes the
      #      ?target= query parameter,
      #   2. `instance` — the label that ends up on every sample — becomes that
      #      URL, so the series reads like the site rather than like 127.0.0.1,
      #   3. `__address__`, which is what Prometheus actually connects to, is
      #      overwritten with the local exporter.
      #
      # Drop rule 3 and Prometheus tries to dial "https://git.mauderer.work" as
      # a host:port and every probe is down forever.
      job_name = "blackbox-http";
      metrics_path = "/probe";
      params.module = [ "http_2xx" ];
      # A public round trip through the Cloudflare edge every 30s is traffic
      # for nothing; uptime at minute resolution is plenty.
      scrape_interval = "60s";
      static_configs = [ { targets = probeTargets; } ];
      relabel_configs = [
        {
          source_labels = [ "__address__" ];
          target_label = "__param_target";
        }
        {
          source_labels = [ "__param_target" ];
          target_label = "instance";
        }
        {
          target_label = "__address__";
          replacement = "127.0.0.1:${toString blackboxPort}";
        }
      ];
    };
  };

  # The exporter connects to the Unix socket at startup; without this it races
  # postgresql.service on boot and spends the first scrape interval logging a
  # connection refusal. Ordering only — the exporter retries, so it must not
  # fail to start just because the cluster is down.
  systemd.services.prometheus-postgres-exporter = {
    after = [ "postgresql.target" ];
    wants = [ "postgresql.target" ];
  };
}
