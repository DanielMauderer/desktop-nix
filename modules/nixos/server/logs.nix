# Logs half of the observability stack: Loki as the log store, Grafana Alloy as
# the agent that ships this host's systemd journal into it. metrics.nix is the
# matching half for metrics; grafana.nix reads both.
#
# Exposure (no new WAN ports; the WAN surface stays UDP 51820 + TCP 80/443):
#   3100  Loki's HTTP API — push *and* query. This is the one piece of the stack
#         other machines talk to, so unlike Prometheus it cannot be loopback
#         only: it is admitted from the podman bridge (containerised deployments
#         on this box), the LAN and the wg0 VPN by a source-restricted nftables
#         rule. Never globally open.
#   9096  Loki's gRPC port, 127.0.0.1 only. A single-binary Loki still starts a
#         gRPC server for its internal component wiring; there are no ring peers
#         to reach it, so it stays on loopback.
#  12345  Alloy's own HTTP server (its UI and /metrics), left at the upstream
#         default bind of 127.0.0.1. Prometheus scrapes it over loopback.
#
# `extraInputRules` rather than `allowedTCPPorts` for :3100, for the same reason
# nfs.nix and forgejo.nix do it: the port must never be globally open, and
# stating the source ranges keeps the "WAN TCP surface is exactly 80/443"
# assertion in flake.nix exact rather than approximately true.
#
# Note there is no authentication on :3100 (`auth_enabled = false` means Loki
# does not read the multi-tenancy header, not that it checks credentials). The
# source restriction *is* the access control, which is why the rule lists three
# named subnets instead of an interface.
#
# Storage: everything lives on the mirrored ZFS pool. Logs are bulky and grow
# without bound, which is exactly the workload the OS SSD should not carry, and
# unlike Prometheus' TSDB (see metrics.nix) Loki's paths are plain config values
# rather than a systemd StateDirectory, so they can simply be pointed at the
# pool. Retention is enforced by the compactor at 90 days — matching Prometheus'
# retention, so a dashboard's metrics and logs run out of history together.
{ lib, ... }:
let
  dataDir = "/hdd_pool_1/services/loki";

  httpPort = 3100;
  grpcPort = 9096;

  # Keep in sync with forgejo.nix and nfs.nix — same LAN, same VPN subnet as
  # wireguard.nix, same podman bridge as the NPM container and Actions jobs.
  lanSubnet = "192.168.178.0/24";
  vpnSubnet = "10.100.0.0/24";
  podmanSubnet = "10.88.0.0/16";

  retention = "90d";

  # Alloy's config language. Journal records carry their metadata as
  # `__journal_*` labels, which are dropped unless a relabel rule promotes them:
  # without this block every line would land under a single `job` label and be
  # impossible to filter by unit.
  #
  # Only low-cardinality fields are promoted. Loki builds one stream per unique
  # label combination, and a high-cardinality label (PID, message id) turns a
  # handful of streams into thousands, which is the classic way to make a Loki
  # instance unusable. Everything else stays searchable in the line itself.
  alloyConfig = ''
    // Promote the journal metadata worth indexing into real labels.
    loki.relabel "journal" {
      // Required by the component even though the rules are consumed by
      // reference (via loki.relabel.journal.rules) rather than forwarded here.
      forward_to = []

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

    // Read the journal and forward to the local Loki.
    loki.source.journal "read" {
      forward_to    = [loki.write.local.receiver]
      relabel_rules = loki.relabel.journal.rules
      labels        = { job = "systemd-journal" }

      // On a cold start (or after Alloy has been down) only backfill half a
      // day, so a restart cannot replay months of journal into Loki and trip
      // the ingestion rate limit.
      max_age = "12h"
    }

    loki.write "local" {
      endpoint {
        url = "http://127.0.0.1:${toString httpPort}/loki/api/v1/push"
      }
    }
  '';
in
{
  services.loki = {
    enable = true;

    # `dataDir` is deliberately left at its /var/lib default: it only becomes
    # the unit's WorkingDirectory, while every path that actually holds data is
    # set below and points at the pool. Overriding it would additionally couple
    # the unit's StateDirectory to the pool for no benefit.
    configuration = {
      # Single-tenant. This switches off the X-Scope-OrgID requirement; it is
      # not authentication — see the header note.
      auth_enabled = false;

      server = {
        http_listen_address = "0.0.0.0";
        http_listen_port = httpPort;
        grpc_listen_address = "127.0.0.1";
        grpc_listen_port = grpcPort;
        log_level = "info";
      };

      # Single-binary mode: one process playing every role, with the hash ring
      # held in memory instead of consul/etcd.
      common = {
        instance_addr = "127.0.0.1";
        path_prefix = dataDir;
        replication_factor = 1;
        ring.kvstore.store = "inmemory";
        storage.filesystem = {
          chunks_directory = "${dataDir}/chunks";
          rules_directory = "${dataDir}/rules";
        };
      };

      # TSDB index + schema v13: the current combination, and the one that
      # structured metadata and the volume API require. The `from` date is when
      # this config first applied — it must stay in the past, and must never be
      # edited in place once Loki has written data under it (a schema change is
      # a *new* entry with a future `from`, or Loki can no longer find its old
      # index).
      schema_config.configs = [
        {
          from = "2026-01-01";
          store = "tsdb";
          object_store = "filesystem";
          schema = "v13";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }
      ];

      storage_config = {
        tsdb_shipper = {
          active_index_directory = "${dataDir}/tsdb-index";
          cache_location = "${dataDir}/tsdb-cache";
        };
        filesystem.directory = "${dataDir}/chunks";
      };

      # Retention is the compactor's job in Loki 3.x; `delete_request_store` is
      # mandatory once `retention_enabled` is set.
      compactor = {
        working_directory = "${dataDir}/compactor";
        retention_enabled = true;
        delete_request_store = "filesystem";
      };

      limits_config = {
        retention_period = retention;

        # Headroom for deployment logs on top of the host journal, with a burst
        # allowance for a service that dumps a stack trace.
        ingestion_rate_mb = 16;
        ingestion_burst_size_mb = 32;

        # Powers the log-volume histogram in Grafana's Explore view.
        volume_enabled = true;
      };

      # No phone-home.
      analytics.reporting_enabled = false;
    };
  };

  # The journal shipper. Alloy replaces Promtail, which reached end of life
  # upstream in early 2026; the config language is more verbose but this is the
  # component that will still exist in a year.
  services.alloy = {
    enable = true;
    # Stated rather than relying on the module default, since the config file
    # written below has to land where the unit looks for it. Alloy loads every
    # *.alloy file in this directory.
    configPath = "/etc/alloy";
  };

  environment.etc."alloy/config.alloy".text = alloyConfig;

  systemd.services.alloy = {
    # Alloy runs under DynamicUser, so journal access is not inherited from
    # anywhere — without this group the source component starts and reads
    # nothing but its own messages.
    serviceConfig.SupplementaryGroups = [ "systemd-journal" ];
    # Ordering only, never a Requires: Alloy retries pushes with backoff, so it
    # must survive Loki being down rather than refusing to start with it.
    after = [ "loki.service" ];
  };

  # :3100 is admitted only from the three named sources. The podman bridge is
  # the interesting one — it is what lets a containerised deployment on this box
  # push its logs — and matches the subnet forgejo.nix already names.
  networking.firewall.extraInputRules = ''
    ip saddr { ${podmanSubnet}, ${lanSubnet}, ${vpnSubnet} } tcp dport ${toString httpPort} accept
  '';

  # `extraInputRules` exists only on the nftables backend and is silently
  # ignored under iptables, which would leave :3100 unreachable rather than
  # merely unrestricted. core/hardening.nix already turns nftables on for every
  # host; this default keeps the module honest on its own (the VM test node
  # relies on it) without overriding a host that sets it explicitly. Same
  # arrangement as forgejo.nix.
  networking.nftables.enable = lib.mkDefault true;

  # Every path above is on the ZFS pool, which systemd.tmpfiles cannot create
  # because it runs before zfs-mount.service. Same fix as npm-data-dirs,
  # forgejo-dump-dirs and paperless-data-dirs: a oneshot inside loki.service's
  # own dependency chain, so it cannot run before the pool is mounted. The
  # requiredBy/before pair also orders loki.service after the mount, so that
  # unit needs no extra ordering of its own.
  systemd.services.loki-data-dirs = {
    requires = [ "zfs-mount.service" ];
    after = [ "zfs-mount.service" ];
    before = [ "loki.service" ];
    requiredBy = [ "loki.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    # /hdd_pool_1/services is shared with npm, forgejo, paperless and grafana,
    # and none of those oneshots are ordered against each other — so all of them
    # must leave the parent in the same state or the last one to run locks the
    # others out of their own subtree. The agreed state is root:root 0755:
    # world-*traversable* so every unprivileged service can reach its own
    # directory, while each subtree stays 0750 and owned by its service. The
    # pool *root* is chmodded for the same reason: zfs.nix imports hdd_pool_1
    # untouched, so its mode is inherited from the box's former install and is
    # not traversable by service users. See server/README.md.
    script = ''
      mkdir -p ${dataDir}/chunks ${dataDir}/rules ${dataDir}/tsdb-index \
        ${dataDir}/tsdb-cache ${dataDir}/compactor
      chmod 0755 /hdd_pool_1 /hdd_pool_1/services
      # Only the directories this unit creates, never `chown -R`: loki owns
      # everything it writes below them, and recursing would re-walk every
      # chunk on the pool on each boot.
      chown loki:loki ${dataDir} ${dataDir}/chunks ${dataDir}/rules \
        ${dataDir}/tsdb-index ${dataDir}/tsdb-cache ${dataDir}/compactor
      chmod 0750 ${dataDir}
    '';
  };
}
