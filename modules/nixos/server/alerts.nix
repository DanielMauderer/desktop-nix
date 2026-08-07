# Alert delivery: a systemd `OnFailure=` handler that pushes to the ntfy
# instance this box already runs (ntfy.nix), and the sops credential both it and
# Grafana's contact point (grafana.nix) authenticate with.
#
# Exposure (no new WAN ports; the WAN surface stays UDP 51820 + TCP 80/443):
#   none. The notifier is an outbound POST to 127.0.0.1:2586.
#
# ## Why systemd and not only Grafana
#
# Grafana can alert on anything in the TSDB and gets the interesting rules (disk
# filling, a backup going stale, a certificate not renewing). What it cannot do
# is tell you that *Grafana* died — or Prometheus, or the box's power. This half
# is the floor under that: a unit fails, systemd starts the handler, the handler
# POSTs. It involves no scrape, no evaluation interval and no database, so it
# still works when the observability stack is the thing that broke. The two are
# complementary and the overlap (both can report a failed `nixos-upgrade`) is
# deliberate.
#
# ## Why the credential is a password and not a token
#
# ntfy runs closed (`auth-default-access: deny-all`), so publishing needs an
# account. ntfy's tokens can only be minted by ntfy itself, which would make the
# value in sops a copy of something created on the server — a round trip, and a
# second source of truth. A password goes the other way: the value here is
# authoritative and `ntfy user add` on the server consumes it, so the install
# step reads out of sops rather than writing back into it. See the ntfy section
# of hosts/home-server/INSTALL.md.
#
# The password never reaches the Nix store: the handler reads the decrypted file
# at runtime, and Grafana's contact point is generated at activation (see
# grafana.nix). `curl --netrc-file` rather than `-u`, because `-u` puts the
# credential in the process' argv, which is world-readable in /proc.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # ntfy.nix. Loopback rather than the public URL: the notifier runs on the same
  # box, so there is no reason for the notification to leave and come back
  # through NPM — and this path keeps working when DNS or the certificate is the
  # thing that broke.
  ntfyLocal = "http://127.0.0.1:2586";

  # The account created in INSTALL.md, and the topic its ACL grants. Publishing
  # is restricted to this one topic, so a leaked password cannot post anywhere
  # else on the instance.
  alertUser = "alerts";
  alertTopic = "home-server";

  passwordFile = config.sops.secrets.ntfy-alert-password.path;

  # Where the generated Grafana contact point lands. /run, not the store and
  # not the pool: it holds the publish password, and it is cheap to regenerate
  # on every boot.
  contactPointDir = "/run/grafana-alerting";
  contactPointFile = "${contactPointDir}/contactPoints.yaml";

  # ntfy's message templating, which is the piece that makes a Grafana webhook
  # readable on a phone. Without `template=yes` ntfy takes the request body
  # verbatim as the message — and Grafana's body is a JSON document, so the
  # notification would be a wall of braces. With it, these two Go templates are
  # evaluated against that JSON and only the interesting fields come through.
  #
  # Passed as query parameters because Grafana's webhook integration sends a
  # body it composes itself and exposes no way to set request headers, so the
  # URL is the only channel available.
  ntfyParams = lib.concatStringsSep "&" [
    "template=yes"
    "title=%7B%7B.title%7D%7D" # {{.title}}
    "message=%7B%7B.message%7D%7D" # {{.message}}
    "priority=high"
    "tags=rotating_light"
  ];

  # Units whose failure is worth waking someone for. Everything here either
  # loses data when it stops (the three backups), stops the box updating
  # itself, or is part of the observability stack — which failing silently is
  # exactly the situation this module exists to prevent.
  #
  # Named explicitly rather than derived: `onFailure` is attached by *defining*
  # the unit, so a name that does not exist on this host would quietly create a
  # broken unit rather than fail. Every name here is checked against the running
  # config by an assertion in flake.nix.
  watchedUnits = [
    # Updates
    "nixos-upgrade"
    # Backups — the only copies that survive losing the SSD
    "forgejo-dump"
    "paperless-exporter"
    "postgresqlBackup"
    # Storage
    "zfs-scrub"
    # The observability stack itself
    "prometheus"
    "loki"
    "grafana"
    "alloy"
    # ...including the two textfile writers, whose failure would otherwise show
    # up only as metrics quietly going stale.
    "nixos-metrics"
    "backup-metrics"
  ];

  ntfyUrl = "${ntfyLocal}/${alertTopic}?${ntfyParams}";

  # Every rule is one instant PromQL query whose *presence* is the alert. There
  # is no threshold expression anywhere below, because each `expr` is written so
  # that it returns no series at all when things are fine — `up == 0` matches
  # nothing while every target is up. That keeps a rule readable as a single
  # line and keeps the generated YAML close to what a human would write in the
  # UI.
  #
  # `noDataState = "OK"`, always. Grafana's default is `NoData`, which *alerts*
  # on an absent series — and absence is the normal state for every rule here by
  # construction. Left at the default, this whole group would fire permanently.
  # The cost is that a series disappearing entirely (an exporter that stopped)
  # is not caught by these rules; that is what the `up == 0` rule and the
  # OnFailure handler are for.
  rule =
    {
      uid,
      title,
      expr,
      for ? "10m",
      summary,
    }:
    {
      inherit uid title;
      condition = "A";
      data = [
        {
          refId = "A";
          # The window only has to cover one scrape interval (30s) for an
          # instant query; 10 minutes leaves room for a target that scrapes
          # slowly without changing what is evaluated.
          relativeTimeRange = {
            from = 600;
            to = 0;
          };
          datasourceUid = "prometheus";
          model = {
            refId = "A";
            editorMode = "code";
            instant = true;
            range = false;
            inherit expr;
            intervalMs = 1000;
            maxDataPoints = 43200;
          };
        }
      ];
      noDataState = "OK";
      # An evaluation that errors is a real problem — a datasource that is gone,
      # a query that no longer parses — and must not be silently treated as OK.
      execErrState = "Error";
      "for" = for;
      annotations.summary = summary;
      labels = { };
    };

  alertRules = map rule [
    {
      uid = "hs-target-down";
      title = "Prometheus target down";
      expr = "up == 0";
      summary = "{{ $labels.job }} has not answered a scrape for 10 minutes.";
    }
    {
      uid = "hs-unit-failed";
      title = "systemd unit failed";
      expr = "node_systemd_unit_state{state=\"failed\"} == 1";
      summary = "{{ $labels.name }} is in the failed state.";
    }
    {
      uid = "hs-root-filling";
      title = "Root filesystem filling up";
      expr = "node_filesystem_avail_bytes{mountpoint=\"/\"} / node_filesystem_size_bytes{mountpoint=\"/\"} < 0.15";
      for = "15m";
      summary = "Less than 15% free on the SSD root. Prometheus' TSDB and every service's state live here.";
    }
    {
      uid = "hs-pool-filling";
      title = "ZFS pool filling up";
      expr = "node_filesystem_avail_bytes{mountpoint=\"/hdd_pool_1\"} / node_filesystem_size_bytes{mountpoint=\"/hdd_pool_1\"} < 0.15";
      for = "15m";
      summary = "Less than 15% free on hdd_pool_1. Loki retention and the backups both grow here.";
    }
    {
      uid = "hs-smart-failing";
      title = "Drive reports SMART failure";
      expr = "smartctl_device_smart_status == 0";
      summary = "{{ $labels.device }} is predicting failure. Replace it before the vdev degrades.";
    }
    {
      # Freshness *and* size, because mtime alone is not enough: a dump that
      # failed halfway still updates the timestamp, which is precisely the
      # silent failure backup-metrics.nix exists to catch.
      uid = "hs-backup-stale";
      title = "Backup is stale or empty";
      expr = "(time() - (backup_last_success_timestamp_seconds > 0) > 129600) or (backup_last_size_bytes == 0)";
      for = "1h";
      summary = "The {{ $labels.job }} backup is older than 36 hours or wrote nothing. It runs nightly.";
    }
    {
      uid = "hs-cert-expiring";
      title = "TLS certificate expiring";
      expr = "(probe_ssl_earliest_cert_expiry - time()) / 86400 < 21";
      for = "1h";
      summary = "{{ $labels.instance }}'s certificate expires in under 21 days; NPM renews at 30, so renewal has stopped.";
    }
    {
      uid = "hs-probe-failing";
      title = "Synthetic probe failing";
      expr = "probe_success == 0";
      for = "15m";
      summary = "{{ $labels.job }} for {{ $labels.instance }} has been failing for 15 minutes.";
    }
    {
      uid = "hs-nixpkgs-stale";
      title = "System has stopped updating";
      expr = "time() - (nixos_nixpkgs_timestamp_seconds > 0) > 604800";
      for = "6h";
      summary = "The running system's nixpkgs is over a week old — the nightly lock bump or autoUpgrade has stalled.";
    }
    {
      uid = "hs-reboot-pending";
      title = "Reboot pending";
      expr = "nixos_reboot_required == 1";
      # autoUpgrade runs with allowReboot = false, so this is a nudge, not an
      # incident. A week of grace keeps a routine kernel bump from paging on the
      # night it lands.
      for = "7d";
      summary = "A newer kernel has been activated but not booted for a week.";
    }
    {
      uid = "hs-textfile-stale";
      title = "Textfile metrics are stale";
      expr = "time() - node_textfile_mtime_seconds > 21600";
      for = "1h";
      summary = "A .prom writer has not run in 6 hours; the update and backup metrics on the dashboards are no longer current.";
    }
  ];

  notifier = pkgs.writeShellScript "notify-failure" ''
    set -uo pipefail
    export PATH=${
      lib.makeBinPath (
        with pkgs;
        [
          coreutils
          curl
          systemd
        ]
      )
    }

    unit="''${1:?usage: notify-failure UNIT}"

    # A netrc rather than `-u user:pass`: argv is world-readable through
    # /proc/<pid>/cmdline for as long as the process lives.
    netrc=$(mktemp)
    trap 'rm -f "$netrc"' EXIT
    printf 'machine 127.0.0.1 login %s password %s\n' \
      ${lib.escapeShellArg alertUser} "$(cat ${passwordFile})" > "$netrc"

    # The last few journal lines, so the notification carries the cause and not
    # just the name. Truncated hard — this ends up on a phone screen, and ntfy
    # rejects oversized bodies.
    body=$(journalctl -u "$unit" -n 15 --no-pager -o cat 2>/dev/null | tail -c 3000)
    [ -n "$body" ] || body="(no journal output)"

    # Failures are the one thing that must not be swallowed by a retry budget,
    # but they also must not hang a systemd job: bounded, with retries, and
    # never blocking longer than a minute in total.
    curl --netrc-file "$netrc" \
      --silent --show-error --fail \
      --max-time 20 --retry 3 --retry-delay 5 --retry-max-time 60 \
      -H "Title: $unit failed on ${config.networking.hostName}" \
      -H "Priority: high" \
      -H "Tags: rotating_light" \
      -d "$body" \
      ${ntfyLocal}/${alertTopic}
  '';
in
{
  # Decrypted at activation. Root-owned at the default: the handler runs as
  # root, and the contact-point generator below runs as root too.
  sops.secrets.ntfy-alert-password = {
    sopsFile = ../../../secrets/home-server/ntfy.yaml;
  };

  # ---------------------------------------------------------------------------
  # Grafana's half: everything that needs the TSDB to notice.
  #
  # These live here rather than in grafana.nix so that "how does this box tell
  # me something is wrong" is one file. grafana.nix owns the service; this owns
  # the alerting policy on top of it.
  # ---------------------------------------------------------------------------

  services.grafana.provision.alerting = {
    # `path` rather than `settings`, and this is the whole reason the generator
    # unit below exists: `settings` is rendered into the world-readable Nix
    # store, and a contact point necessarily holds the publish password.
    # Upstream symlinks whatever `path` names into the provisioning directory,
    # so a path under /run resolves at runtime — the store gets a dangling
    # symlink and never the secret.
    contactPoints.path = contactPointFile;

    # The root route. Provisioning this replaces Grafana's default policy,
    # which points at a nonexistent email contact point — so without it every
    # rule below would fire into nothing.
    policies.settings = {
      apiVersion = 1;
      policies = [
        {
          orgId = 1;
          receiver = "ntfy";
          group_by = [ "alertname" ];
          group_wait = "30s";
          group_interval = "5m";
          # A still-firing alert re-notifies twice a day. Often enough not to be
          # forgotten, rarely enough that a long-running condition (a drive that
          # will not be replaced this week) does not train the phone to be
          # ignored.
          repeat_interval = "12h";
        }
      ];
    };

    rules.settings = {
      apiVersion = 1;
      groups = [
        {
          orgId = 1;
          name = "home-server";
          folder = "NixOS";
          interval = "1m";
          rules = alertRules;
        }
      ];
    };
  };

  # Writes the contact point from the decrypted secret, before Grafana starts.
  # Same shape as the grafana-data-dirs oneshot next door: inside grafana's own
  # dependency chain, so it cannot be skipped and cannot run too late.
  systemd.services =
    # Attach the handler to every watched unit. `%n` expands to the *full* name
    # of the failing unit, suffix included, so the handler instance for
    # `loki.service` is `notify-failure@loki.service.service` — that reads
    # oddly and is correct; inside the template `%i` is then `loki.service`,
    # which is exactly what `journalctl -u` wants.
    lib.genAttrs watchedUnits (_: {
      onFailure = [ "notify-failure@%n.service" ];
    })
    // {
      # A template, so one unit covers every watched service.
      "notify-failure@" = {
        description = "Push a failure notification for %i to ntfy";

        # Ordered after ntfy so a failure during boot does not race the thing
        # it posts to. Deliberately not `requires`: if ntfy is down this should
        # fail loudly in the journal, not refuse to run — and it must never
        # pull ntfy into the dependency graph of the units it watches.
        after = [ "ntfy-sh.service" ];

        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${notifier} %i";

          # No sandbox beyond this: it needs the journal of an arbitrary unit
          # and the decrypted secret. It makes one loopback request and writes
          # nothing but a temporary netrc.
          PrivateTmp = true;
        };
      };

      # Writes the contact point from the decrypted secret, before Grafana
      # starts. Same shape as the grafana-data-dirs oneshot next door: inside
      # grafana's own dependency chain, so it cannot be skipped and cannot run
      # too late.
      grafana-contact-points = {
        description = "Generate Grafana's ntfy contact point from the sops secret";
        before = [ "grafana.service" ];
        requiredBy = [ "grafana.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        # 0640 root:grafana. The rest of Grafana's provisioning directory is
        # world-readable Nix store; this file is the one part that holds a
        # password, so it is not.
        script = ''
          umask 0027
          mkdir -p ${contactPointDir}
          cat > ${contactPointFile} <<EOF
          apiVersion: 1
          contactPoints:
            - orgId: 1
              name: ntfy
              receivers:
                - uid: ntfy-home-server
                  type: webhook
                  disableResolveMessage: false
                  settings:
                    url: ${ntfyUrl}
                    httpMethod: POST
                    username: ${alertUser}
                    password: $(cat ${passwordFile})
          EOF
          chown root:grafana ${contactPointDir} ${contactPointFile}
          chmod 0750 ${contactPointDir}
          chmod 0640 ${contactPointFile}
        '';
      };
    };
}
