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
# deliberate — though no longer simultaneous: this half still pushes on the
# first failed run, with the journal lines that say why, while the Grafana rule
# waits to see whether the next night's run failed too.
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

  # Units that retry on a timer of their own, and are therefore carved out of
  # the general `hs-unit-failed` rule below into rules of their own.
  #
  # The general rule reports a unit that has been failed for ten minutes, which
  # is the right question for a unit that stays down until somebody fixes it.
  # For a unit that has another go on its own it is the wrong one: the failure
  # is over before it can be acted on, so every notification is stale by the
  # time it arrives — and a notification that is never actionable is one the
  # phone learns to ignore. What matters for these is whether the *retry* also
  # failed, which is what the dedicated rules ask.
  #
  # Both lists are checked against the running config by an assertion in
  # flake.nix: a name here that matches no unit would silently hand that unit
  # back to the general rule, which is the noise these rules exist to remove.

  # Every five minutes, from a timer (upstream's, and `startAt` on the second
  # instance — see server/cloudflare-ddns.nix). A single failed run is the
  # normal shape of the ISP dropping the line: the discovery service has no
  # route, the run exits non-zero, and the run five minutes later publishes the
  # new prefix and clears it.
  dyndnsUnits = [
    "cloudflare-dyndns.service"
    "cloudflare-dyndns-vpn.service"
  ];

  # Daily, from `system.autoUpgrade` (core/updates.nix) with 45 minutes of
  # jitter. One failed run is usually a transient upstream — a substituter
  # timing out, a broken nixpkgs revision that the next lock bump moves past —
  # and cannot be acted on before the next run anyway, since `allowReboot =
  # false` means the fix is a rebuild rather than an intervention.
  upgradeUnits = [ "nixos-upgrade.service" ];

  retryingUnits = dyndnsUnits ++ upgradeUnits;

  # A `name` selector for a set of units. `=~`/`!~` are anchored in RE2, so the
  # alternation matches whole unit names.
  #
  # Escaped twice, and both halves are load-bearing. `escapeRegex` is for RE2,
  # where an unescaped `.` matches any character; `escape [ "\\" ]` is for the
  # PromQL string literal the regex is written inside, whose escape sequences
  # follow Go's — a lone `\.` there is not a regex escape but a parse error,
  # and a rule that fails to parse does not go quiet, it alerts
  # (`execErrState = "Error"`).
  unitsRe = names: lib.concatMapStringsSep "|" (n: lib.escape [ "\\" ] (lib.escapeRegex n)) names;

  # "Failed now, and still failed one retry interval ago." Both halves read the
  # same metric with the same selector, so the `and` matches label set for label
  # set and the answer is per unit.
  #
  # The window is in the query rather than in `for`, because Grafana's pending
  # timer is reset by any evaluation that returns no series — and each retry
  # takes the unit through `activating`, where the failed series is 0. A `for`
  # long enough to cover several retries would be reset by every one of them and
  # the alert would never fire at all. An `offset` has no such state: it is two
  # instant reads of the TSDB, so a retry in between is exactly what it is
  # measuring rather than something that resets it.
  sustainedFailure =
    { units, offset }:
    let
      failed =
        suffix:
        ''node_systemd_unit_state{job="node",state="failed",name=~"${unitsRe units}"}${suffix} == 1'';
    in
    "(${failed ""}) and (${failed " offset ${offset}"})";

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
      window ? 600,
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
          # slowly without changing what is evaluated. A query that reaches
          # further back with `offset` passes its own `window` rather than
          # relying on that slack.
          relativeTimeRange = {
            from = window;
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
      # `job="node"` here is not decoration. This Prometheus also holds the
      # workstations' series, pushed in by modules/nixos/net/telemetry.nix under
      # job="client-node" — and a desktop carries ~1000 unit-state series of its
      # own. Unscoped, a laptop's failed unit would page as a home-server alert,
      # which is the outcome the push design exists to avoid. Every rule below
      # that reads a node/smartctl metric is pinned for the same reason; the
      # dashboards in dashboards/ are pinned to match.
      #
      # `name!~` excludes the self-retrying units; the two rules after this one
      # are their replacement, and the exclusion is what keeps this rule from
      # firing first and making them pointless.
      uid = "hs-unit-failed";
      title = "systemd unit failed";
      expr = ''node_systemd_unit_state{job="node",state="failed",name!~"${unitsRe retryingUnits}"} == 1'';
      summary = "{{ $labels.name }} is in the failed state.";
    }
    {
      # An hour is twelve retries. Nothing transient survives that: either the
      # line is still down or the token has been revoked, and both are worth
      # knowing about because the AAAA records are stale from here on — the
      # wildcard is the origin behind Cloudflare's proxy and `vpn.` is the
      # WireGuard endpoint, so a prefix change that never gets published takes
      # the VPN out with it.
      uid = "hs-dyndns-unit-failed";
      title = "Dynamic DNS has been failing for an hour";
      expr = sustainedFailure {
        units = dyndnsUnits;
        offset = "1h";
      };
      window = 3600 + 600;
      # The timeframe is the query's, not a pending window's; see the comment on
      # `sustainedFailure`.
      for = "0s";
      summary = "{{ $labels.name }} has been failed for an hour. It retries every 5 minutes, so this is not a blip — the published AAAA records are stale.";
    }
    {
      # A day is one retry. Offset by 24h rather than the 24h45m the jitter
      # allows for: the run itself sits in `activating` for as long as it takes
      # to build, so by the time the second failure lands the sample a day back
      # is comfortably inside the first failure rather than near its edge.
      #
      # This is the short-horizon half of a pair. `hs-nixpkgs-stale` is the
      # other: it catches an update pipeline that has stopped moving for a week
      # regardless of *why* — including the case where nothing fails because
      # nothing runs.
      uid = "hs-upgrade-unit-failed";
      title = "System upgrade has failed two nights running";
      expr = sustainedFailure {
        units = upgradeUnits;
        offset = "24h";
      };
      window = 86400 + 600;
      for = "0s";
      summary = "{{ $labels.name }} failed again after a day. The nightly update has stopped landing, so the box is no longer picking up the lock bumps.";
    }
    {
      uid = "hs-root-filling";
      title = "Root filesystem filling up";
      expr = "node_filesystem_avail_bytes{job=\"node\",mountpoint=\"/\"} / node_filesystem_size_bytes{job=\"node\",mountpoint=\"/\"} < 0.15";
      for = "15m";
      summary = "Less than 15% free on the SSD root. Prometheus' TSDB and every service's state live here.";
    }
    {
      # Already safe on the mountpoint alone — no client has /hdd_pool_1 — but
      # pinned anyway so the whole group reads the same way and a future rule
      # copied from here inherits the selector rather than the omission.
      uid = "hs-pool-filling";
      title = "ZFS pool filling up";
      expr = "node_filesystem_avail_bytes{job=\"node\",mountpoint=\"/hdd_pool_1\"} / node_filesystem_size_bytes{job=\"node\",mountpoint=\"/hdd_pool_1\"} < 0.15";
      for = "15m";
      summary = "Less than 15% free on hdd_pool_1. Loki retention and the backups both grow here.";
    }
    {
      uid = "hs-smart-failing";
      title = "Drive reports SMART failure";
      expr = "smartctl_device_smart_status{job=\"smartctl\"} == 0";
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
      expr = "time() - node_textfile_mtime_seconds{job=\"node\"} > 21600";
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
