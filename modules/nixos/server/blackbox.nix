# Synthetic probes: `services.prometheus.exporters.blackbox`, scraped by
# metrics.nix. Everything else in the stack measures the box from the inside —
# this measures the services the way a client reaches them.
#
# Exposure (no new WAN ports; the WAN surface stays UDP 51820 + TCP 80/443):
#   9115  the exporter, bound to 127.0.0.1 and never firewalled open, like every
#         other exporter here. Note this one is a *client*: it makes outbound
#         connections on Prometheus' behalf, which is why /probe must not be
#         reachable from anywhere else — an open blackbox exporter is an
#         request-forwarder that will fetch any URL a caller names.
#
# ## What these probes do and do not prove
#
# They do not prove the services are reachable from the internet. The probes run
# on the box being probed, so a request to a public hostname either hairpins
# through the router or never leaves at all; it can pass while the WAN path is
# broken and fail while it is fine. Verifying reachability from outside needs a
# prober somewhere else, which this repo does not have. Read every panel on the
# uptime dashboard with that caveat.
#
# What they do prove is the half that actually breaks here:
#
#   * **certificates.** NPM owns the Let's Encrypt certificates and renews them
#     itself, inside a container, on a schedule nothing in this repo can see. An
#     expiry countdown is the only warning before a renewal that quietly stopped
#     working takes a public hostname offline.
#   * **proxy routing.** The public probes go to 127.0.0.1:443 — NPM publishes
#     :443 on all interfaces (reverse-proxy.nix), so loopback reaches it — with
#     the real hostname supplied as SNI and as the Host header. That traverses
#     the entire proxy chain, TLS termination and backend routing included,
#     without depending on DNS or on the router hairpinning. If a proxy host is
#     misconfigured in NPM's UI (which is where proxy hosts live — they are not
#     in Nix), this is what notices.
#   * **DNS.** cloudflare-ddns.nix republishes the box's IPv6 into Cloudflare
#     every five minutes. Asking a public resolver for the record is how a
#     stalled updater becomes visible; nothing else here would show it.
#
# ## Certificate verification is real here
#
# `insecure_skip_verify` is deliberately *not* set. Connecting to 127.0.0.1
# while asking for a certificate valid for `ntfy.mauderer.work` works because
# `tls_config.server_name` drives both SNI and the name the certificate is
# checked against — so the probe fails if NPM starts serving the wrong
# certificate for that hostname, which is exactly the fault worth catching.
{ lib, pkgs, ... }:
let
  blackboxPort = 9115;

  # reverse-proxy.nix publishes the NPM container's :443 on all interfaces.
  proxyHttpsPort = 443;

  # The hostnames NPM terminates TLS for, each with its own Let's Encrypt
  # certificate. Kept as literals in sync with forgejo.nix and ntfy.nix, the
  # same convention metrics.nix uses for its siblings' ports — adding a proxy
  # host in NPM's UI without adding it here means it simply is not watched.
  publicHosts = [
    "ntfy.mauderer.work" # ntfy.nix
    "git.mauderer.work" # forgejo.nix
  ];

  # Loopback health endpoints, one per service that has one. These overlap with
  # the scrape targets in metrics.nix on purpose: `up` says "the metrics
  # endpoint answered", which for Grafana and Forgejo is a different code path
  # from the one users hit.
  internalTargets = {
    forgejo = "http://127.0.0.1:4000/api/healthz";
    ntfy = "http://127.0.0.1:2586/v1/health";
    grafana = "http://127.0.0.1:3030/api/health";
  };

  # A public resolver rather than the box's own: the question is whether the
  # record cloudflare-ddns publishes is visible to the world, and asking a
  # resolver that might be caching this host's view answers a different one.
  dnsResolver = "1.1.1.1:53";

  # One prober module per public host, because SNI and the expected certificate
  # name are per host and blackbox modules are static.
  tlsModule = host: {
    name = "tls_${lib.replaceStrings [ "." ] [ "_" ] host}";
    value = {
      prober = "http";
      timeout = "10s";
      http = {
        method = "GET";
        # The target URL names 127.0.0.1, so without these two the request
        # would arrive at NPM with no usable SNI and be routed by the default
        # host. Together they make it indistinguishable from a real client's
        # request except for the network path.
        headers.Host = host;
        tls_config.server_name = host;
        # A redirect to the canonical URL is a healthy answer, and several of
        # these do redirect. What is being probed is that NPM routes and the
        # backend responds, not that the first response is a 200.
        valid_status_codes = [
          200
          204
          301
          302
          401
          403
        ];
        fail_if_not_ssl = true;
      };
    };
  };

  # Likewise one DNS module per hostname. For the `dns` prober the *target* is
  # the resolver to ask and the name being asked about lives in the module as
  # `query_name` — the reverse of the http prober, where the target is the
  # thing itself. That is why this cannot be one module with a list of targets.
  dnsModule = host: {
    name = "dns_${lib.replaceStrings [ "." ] [ "_" ] host}";
    value = {
      prober = "dns";
      timeout = "10s";
      dns = {
        query_name = host;
        # cloudflare-ddns.nix publishes AAAA only (IPv6, Cloudflare-proxied).
        query_type = "AAAA";
        transport_protocol = "udp";
        valid_rcodes = [ "NOERROR" ];
        # NOERROR with an empty answer section is what a deleted record looks
        # like, and it is indistinguishable from success without this: require
        # at least one record back.
        validate_answer_rrs.fail_if_not_matches_regexp = [ ".*IN\\s+AAAA\\s+.*" ];
      };
    };
  };

  blackboxConfig = (pkgs.formats.yaml { }).generate "blackbox.yml" {
    modules = {
      http_2xx = {
        prober = "http";
        timeout = "5s";
        http = {
          method = "GET";
          # IPv4 only. The loopback and localhost targets below all resolve to
          # 127.0.0.1, and leaving this on `ip6` (blackbox's default preference)
          # makes every probe pay a failed ::1 attempt first.
          preferred_ip_protocol = "ip4";
          valid_status_codes = [ ]; # any 2xx
        };
      };

    }
    // lib.listToAttrs (map tlsModule publicHosts)
    // lib.listToAttrs (map dnsModule publicHosts);
  };

  # The standard blackbox relabel dance, which is why these jobs cannot use the
  # `localJob` helper in metrics.nix: the thing being scraped is always the
  # exporter, and the thing being *probed* travels as a URL parameter. The three
  # rules move the configured target into `?target=`, keep it as the `instance`
  # label so panels read as the probed thing rather than as 127.0.0.1:9115, and
  # only then rewrite the address to the exporter.
  #
  # `instance` is overridden for the TLS and DNS jobs: their targets are
  # 127.0.0.1:443 and the resolver address respectively, which are the same
  # string for every hostname — so without this every public host would collapse
  # into one indistinguishable series on the dashboard. The hostname is the
  # thing being probed there, so the hostname is what `instance` should say.
  probeJob =
    {
      name,
      module,
      targets,
      instance ? null,
    }:
    {
      job_name = name;
      metrics_path = "/probe";
      params.module = [ module ];
      static_configs = [ { inherit targets; } ];
      relabel_configs = [
        {
          source_labels = [ "__address__" ];
          target_label = "__param_target";
        }
        {
          source_labels = [ "__param_target" ];
          target_label = "instance";
        }
      ]
      ++ lib.optional (instance != null) {
        target_label = "instance";
        replacement = instance;
      }
      ++ [
        {
          target_label = "__address__";
          replacement = "127.0.0.1:${toString blackboxPort}";
        }
      ];
    };
in
{
  services.prometheus.exporters.blackbox = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = blackboxPort;
    configFile = blackboxConfig;
  };

  # Appended to the scrape list metrics.nix builds. `scrapeConfigs` is a list
  # option, so the two definitions merge and neither module has to know the
  # other's contents — the same arrangement forgejo.nix and ntfy.nix use for
  # `extraInputRules`.
  services.prometheus.scrapeConfigs = [
    (probeJob {
      name = "probe-internal";
      module = "http_2xx";
      targets = lib.attrValues internalTargets;
    })
  ]
  ++ lib.concatMap (
    host:
    let
      slug = lib.replaceStrings [ "." ] [ "-" ] host;
      key = lib.replaceStrings [ "." ] [ "_" ] host;
    in
    [
      (probeJob {
        name = "probe-tls-${slug}";
        module = "tls_${key}";
        targets = [ "https://127.0.0.1:${toString proxyHttpsPort}/" ];
        instance = host;
      })
      (probeJob {
        name = "probe-dns-${slug}";
        module = "dns_${key}";
        targets = [ dnsResolver ];
        instance = host;
      })
    ]
  ) publicHosts;
}
