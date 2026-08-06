# Alerting for the observability stack: Grafana's own unified alerting,
# provisioned from Nix, delivered to the ntfy instance this box already runs.
#
# Split out of grafana.nix rather than folded into it because this is the one
# part of the stack with a manual bootstrap (an ntfy token), its own sops
# secret, and a plausible reason to be reverted on its own.
# `services.grafana.provision.alerting.*` merges across modules, so nothing here
# needs grafana.nix's cooperation beyond the datasource uids and the folder name.
#
# Exposure: none. Nothing listens; Grafana makes an outbound POST to ntfy over
# loopback. The WAN surface stays UDP 51820 + TCP 80/443.
#
# Why Grafana alerting and not Alertmanager: Alertmanager would be a fourth
# daemon plus a bridge to translate its webhook into something ntfy understands,
# and it cannot evaluate a Loki query — which rules out the log-based rules
# below. Grafana already runs, already reads both datasources, and its rule
# state lives in the SQLite database that is already on the pool.
#
# Why ntfy and not email: ntfy.nix exists precisely so a service on this box can
# reach the phone with one HTTP POST, off-LAN, with no third party in the path.
# Using it here is what it was set up for.
#
# ── The delivery path, and the two things worth knowing about it ──────────────
#
# Grafana's generic webhook posts *its own* JSON envelope, which ntfy would
# happily publish as a wall of JSON on the phone. The fix is a custom payload
# template (`settings.payload.template`) that emits ntfy's JSON publishing
# format instead, POSTed to ntfy's root URL — which is why `url` below carries
# no topic path: with JSON publishing the topic travels inside the body.
#
#  1. The template lives in the `templates` provisioning file, not inline in
#     `settings`. Grafana interpolates `$VAR` from the environment in `settings`
#     (that is how the token below stays out of the Nix store) but NOT in
#     `templates[].template`. Keeping the Go template out of `settings` means it
#     never has to escape a `$`. It also avoids `$`-prefixed Go variables
#     entirely, so the arrangement is not load-bearing on that distinction.
#  2. The JSON is assembled with `printf "%q"`, which emits a Go-quoted string —
#     valid JSON, with quotes, backslashes and newlines escaped. That matters
#     because alert summaries are free text: hand-written JSON would break the
#     first time a summary contained a quote, and would break *silently*, as a
#     400 from ntfy that nobody sees.
#
# If either half turns out not to work on a future Grafana, the fallback is
# `services.grafana-to-ntfy` (packaged in nixpkgs): a purpose-built bridge that
# takes Grafana's stock webhook and speaks ntfy on the other side. It costs one
# more unit and downgrades the credential from a token to a password. The
# `test-observability` VM test runs a real ntfy and asserts a message actually
# arrives, so a break here fails CI rather than the phone going quiet.
{ config, ... }:
let
  # Keep in sync with ntfy.nix.
  ntfyPort = 2586;
  # The ntfy topic alerts are published to. `svc` (see INSTALL.md §7) has
  # write-only access to '*', so this needs no ACL of its own.
  ntfyTopic = "alerts";

  # Keep in sync with grafana.nix: the same folder its dashboards land in, so a
  # board and the alerts about it sit together. Grafana creates the folder from
  # whichever side provisions first.
  folder = "Home server";

  # Keep in sync with grafana.nix's provisioned datasources.
  promUid = "prometheus";
  lokiUid = "loki";

  # Grafana-managed alert rules are always a three-stage pipeline: a datasource
  # query, a reduce to collapse each series to one number, and a threshold that
  # turns that number into firing/not. The reduce is not optional even for an
  # instant query — the threshold expression takes a number per series, not a
  # series.
  #
  # `condition = "C"` names the threshold stage as the one that decides.
  mkRule =
    {
      uid,
      title,
      expr,
      # "lt" or "gt": which side of `threshold` is the alerting side.
      op,
      threshold,
      summary,
      dsUid ? promUid,
      dsType ? "prometheus",
      for_ ? "10m",
      severity ? "warning",
      # What an empty result means, which differs per rule and is the easiest
      # thing here to get backwards. See the note above each rule below.
      noData ? "Alerting",
    }:
    {
      inherit uid title;
      condition = "C";
      data = [
        {
          refId = "A";
          relativeTimeRange = {
            from = 600;
            to = 0;
          };
          datasourceUid = dsUid;
          # `model` is on Grafana's no-interpolation list, so PromQL and LogQL
          # go in verbatim — no `$` escaping, which is what makes
          # `$__rate_interval`-free expressions safe to write plainly.
          model = {
            refId = "A";
            inherit expr;
            instant = true;
            intervalMs = 1000;
            maxDataPoints = 43200;
            datasource = {
              type = dsType;
              uid = dsUid;
            };
          }
          # Loki needs to be told the query is instant; Prometheus infers it.
          // (if dsType == "loki" then { queryType = "instant"; } else { });
        }
        {
          refId = "B";
          relativeTimeRange = {
            from = 600;
            to = 0;
          };
          datasourceUid = "__expr__";
          model = {
            refId = "B";
            type = "reduce";
            expression = "A";
            reducer = "last";
            # Drop series whose last sample is NaN rather than letting one
            # missing scrape evaluate as "not below the threshold".
            settings.mode = "dropNN";
            datasource = {
              type = "__expr__";
              uid = "__expr__";
            };
          };
        }
        {
          refId = "C";
          relativeTimeRange = {
            from = 600;
            to = 0;
          };
          datasourceUid = "__expr__";
          model = {
            refId = "C";
            type = "threshold";
            expression = "B";
            conditions = [
              {
                evaluator = {
                  type = op;
                  params = [ threshold ];
                };
              }
            ];
            datasource = {
              type = "__expr__";
              uid = "__expr__";
            };
          };
        }
      ];
      noDataState = noData;
      # A rule that cannot evaluate is itself a problem worth hearing about.
      execErrState = "Alerting";
      for = for_;
      labels.severity = severity;
      annotations.summary = summary;
    };
in
{
  services.grafana.provision.alerting = {
    # The notification body. Everything about ntfy's wire format lives here;
    # the contact point below only points at it.
    templates.settings = {
      apiVersion = 1;
      templates = [
        {
          name = "ntfy";
          # ntfy's JSON publishing format: topic in the body, POSTed to the root.
          # Every string value goes through `printf "%q"` so a quote or newline
          # in an alert summary cannot produce invalid JSON.
          #
          # `.CommonAnnotations.summary` is populated because the policy groups
          # by alertname and `summary` is a per-rule annotation — so every alert
          # in a group shares it.
          #
          # Priority 4 (high) while firing, 3 (default) on resolve, so a
          # recovery does not buzz like a failure.
          template = ''
            {{ define "ntfy.payload" -}}
            {"topic":{{ printf "%q" "${ntfyTopic}" }},"title":{{ printf "%s: %s" (.Status | toUpper) (index .CommonLabels "alertname") | printf "%q" }},"message":{{ printf "%d alert(s) | %s" (len .Alerts) (index .CommonAnnotations "summary") | printf "%q" }},"priority":{{ if eq .Status "firing" }}4{{ else }}3{{ end }},"tags":[{{ if eq .Status "firing" }}"rotating_light"{{ else }}"white_check_mark"{{ end }}]}
            {{- end }}
          '';
        }
      ];
    };

    contactPoints.settings = {
      apiVersion = 1;
      contactPoints = [
        {
          name = "ntfy";
          receivers = [
            {
              uid = "ntfy";
              type = "webhook";
              # Send the recovery too — an alert that only ever fires teaches you
              # to ignore it.
              disableResolveMessage = false;
              settings = {
                # The root URL, not /alerts: with JSON publishing the topic is
                # in the body. ntfy binds 0.0.0.0 and the firewall always
                # accepts loopback, so the source-restricted rule in ntfy.nix is
                # not in the way here.
                url = "http://127.0.0.1:${toString ntfyPort}/";
                httpMethod = "POST";

                authorization_scheme = "Bearer";
                # Interpolated by Grafana's provisioner out of the unit's
                # environment (the sops secret below), so the live token is
                # never written into the world-readable Nix store — the same
                # rule as the admin password in grafana.nix, by a different
                # mechanism because this file is YAML rather than the ini.
                authorization_credentials = "$NTFY_ALERT_TOKEN";

                payload.template = ''{{ template "ntfy.payload" . }}'';
              };
            }
          ];
        }
      ];
    };

    # One route, everything to the phone. Provisioning the policy tree replaces
    # it wholesale and makes it read-only in the UI; Grafana's stock
    # `grafana-default-email` contact point still exists but nothing routes to
    # it any more.
    policies.settings = {
      apiVersion = 1;
      policies = [
        {
          receiver = "ntfy";
          # By alertname, so five filesystems crossing a threshold together are
          # one notification. `grafana_folder` comes along because Grafana adds
          # it to every alert and grouping on an ungrouped label splits anyway.
          group_by = [
            "alertname"
            "grafana_folder"
          ];
          group_wait = "30s";
          group_interval = "5m";
          # A disk that has been 92% full for a week should say so twice a day,
          # not every five minutes.
          repeat_interval = "12h";
        }
      ];
    };

    rules.settings = {
      apiVersion = 1;
      groups = [
        {
          name = "home-server";
          inherit folder;
          interval = "1m";
          rules = [
            # ── Capacity ────────────────────────────────────────────────────
            # NoData is Alerting on both: these series exist as long as the node
            # exporter does, so their absence means the exporter is gone.
            (mkRule {
              uid = "fs-root-low";
              title = "Root filesystem low";
              expr = ''100 * node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}'';
              op = "lt";
              threshold = 10;
              for_ = "15m";
              summary = "Less than 10% free on the OS SSD (/). Prometheus' TSDB, the Postgres cluster and Forgejo's state all live here.";
            })
            (mkRule {
              uid = "fs-pool-low";
              title = "ZFS pool low";
              expr = ''100 * node_filesystem_avail_bytes{mountpoint="/hdd_pool_1"} / node_filesystem_size_bytes{mountpoint="/hdd_pool_1"}'';
              op = "lt";
              threshold = 10;
              for_ = "15m";
              summary = "Less than 10% free on hdd_pool_1. Loki's chunks, Grafana's database, and every nightly dump are on this pool.";
            })

            # ── Liveness ────────────────────────────────────────────────────
            # `sum by (name) (...) > 0` returns nothing at all when nothing has
            # failed, so NoData here is the *healthy* case and must be OK — the
            # single easiest thing in this file to get backwards.
            (mkRule {
              uid = "unit-failed";
              title = "systemd unit failed";
              expr = ''sum by (name) (node_systemd_unit_state{state="failed"}) > 0'';
              op = "gt";
              threshold = 0;
              for_ = "5m";
              noData = "OK";
              severity = "critical";
              summary = "At least one systemd unit is in the failed state. Check `systemctl --failed`, or the Failed units panel on the Services dashboard.";
            })
            # `min by (job) (up)` rather than `up == 0`: the former always
            # produces a series, so a down target is a value of 0 rather than an
            # empty result that NoData would have to interpret.
            (mkRule {
              uid = "target-down";
              title = "Prometheus target down";
              expr = "min by (job) (up)";
              op = "lt";
              threshold = 1;
              severity = "critical";
              summary = "A scrape target has been unreachable for 10 minutes — the exporter is down, not necessarily the thing it measures.";
            })

            # ── Backups ─────────────────────────────────────────────────────
            # The failure a unit-state check cannot see: a timer that stops
            # firing is not a failed unit, it is simply nothing at all. The
            # `> 0` filter drops timers that have never run, which would
            # otherwise read as 56 years stale on a fresh install — which is
            # also why NoData is OK rather than Alerting here.
            (mkRule {
              uid = "backup-stale";
              title = "Nightly backup has not run";
              expr = ''max by (name) (time() - (node_systemd_timer_last_trigger_seconds{name=~"forgejo-dump.timer|postgresqlBackup.timer|paperless-exporter.timer"} > 0))'';
              op = "gt";
              threshold = 129600; # 36h — a missed nightly run, with slack.
              for_ = "0s";
              noData = "OK";
              summary = "A nightly dump has not been triggered in over 36 hours. These are the only copies of the forge, the archive and the databases that survive losing the SSD.";
            })

            # ── Hardware ────────────────────────────────────────────────────
            # NoData is OK because this exporter may legitimately not be running
            # at all: the pool sits behind a MegaRAID HBA that often hides the
            # drives from `smartctl --scan`. See the caveat in metrics.nix.
            (mkRule {
              uid = "smart-failing";
              title = "Drive SMART status failing";
              expr = "min by (device) (smartctl_device_smart_status)";
              op = "lt";
              threshold = 1;
              for_ = "0s";
              noData = "OK";
              severity = "critical";
              summary = "A drive is reporting SMART overall-health FAILED. On a mirrored pool this is the warning before a vdev degrades.";
            })
            # Deliberately absent: a rule on ZFS pool health. The node
            # exporter's zfs collector reads /proc/spl/kstat — ARC statistics
            # and per-pool IO — and does not expose `zpool status`, so there is
            # no series to alert on. Adding one means a textfile-collector
            # script running `zpool list -Ho health` on a timer, or the separate
            # zfs_exporter; until then a scrub that fails surfaces through
            # `unit-failed` above.

            # ── The public path ─────────────────────────────────────────────
            (mkRule {
              uid = "probe-down";
              title = "Public endpoint unreachable";
              expr = "min by (instance) (probe_success)";
              op = "lt";
              threshold = 1;
              for_ = "5m";
              severity = "critical";
              summary = "A public hostname has not answered for 5 minutes. This probe covers the whole path — DNS, the Cloudflare edge, NPM and the backend — so the cause may be the dynamic AAAA record rather than the service.";
            })
            (mkRule {
              uid = "cert-expiring";
              title = "TLS certificate expiring";
              expr = "min by (instance) ((probe_ssl_earliest_cert_expiry - time()) / 86400)";
              op = "lt";
              threshold = 14;
              for_ = "0s";
              summary = "A certificate served for a public hostname expires within 14 days. Note this is Cloudflare's edge certificate while the record is proxied — see metrics.nix for probing NPM's own Let's Encrypt certificate instead.";
            })

            # ── Logs ────────────────────────────────────────────────────────
            # The one rule that could not exist under Alertmanager. sshd is
            # admitted on wg0 only, so a burst of failures means someone is on
            # the VPN — which is a different kind of interesting from the usual
            # internet background noise.
            (mkRule {
              uid = "sshd-auth-failures";
              title = "Repeated SSH authentication failures";
              expr = ''sum(count_over_time({unit="sshd.service"} |= "Failed password" [15m]))'';
              op = "gt";
              threshold = 10;
              for_ = "0s";
              noData = "OK";
              dsUid = lokiUid;
              dsType = "loki";
              summary = "More than 10 failed SSH password attempts in 15 minutes. sshd is reachable only over WireGuard, so this comes from inside the VPN.";
            })
          ];
        }
      ];
    };
  };

  # The ntfy publish token. Unlike the two secrets in grafana.nix this one is an
  # ENV-FILE line, not a bare value: it must read exactly
  #
  #   NTFY_ALERT_TOKEN=tk_…
  #
  # because systemd parses it as an EnvironmentFile. Same format as
  # forgejo-runner.nix's token, and the opposite of the Grafana and Cloudflare
  # secrets — the format is per-secret and getting it wrong fails at startup.
  #
  # No `owner`: systemd reads EnvironmentFile as root before dropping to the
  # grafana user, so root-only 0400 is both correct and tighter than handing it
  # to grafana.
  sops.secrets.ntfy-alert-token = {
    sopsFile = ../../../secrets/home-server/ntfy.yaml;
    mode = "0400";
  };

  # No `-` prefix: if the secret is missing, grafana.service must fail loudly
  # rather than come up with an alerting path that silently 401s against ntfy
  # and leaves you believing you are monitored.
  systemd.services.grafana.serviceConfig.EnvironmentFile = config.sops.secrets.ntfy-alert-token.path;
}
