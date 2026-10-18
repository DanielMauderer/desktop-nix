# Public reverse proxy for the home-server: native `services.nginx` with one
# wildcard Let's Encrypt certificate from `security.acme`. Proxy hosts are the
# `vhosts` attrset below — adding a public service is one line here (plus one in
# blackbox.nix's `publicHosts` so it is watched).
#
# Certificates: `*.mauderer.work` + the apex, issued by **DNS-01** through
# Cloudflare with the same `cloudflare-api-token` sops secret cloudflare-ddns.nix
# uses (Zone:DNS:Edit + Zone:Zone:Read). DNS-01 needs no inbound connectivity, so
# it works with the orange cloud left on — which is not optional: the web names
# are proxied AAAA-only, and the Cloudflare proxy is the only path for IPv4
# visitors. It is also the only challenge that can issue a wildcard. lego renews
# at 30 days left via `acme-mauderer.work.timer`. Cloudflare's SSL mode must be
# **Full (strict)**: the origin certificate is a real one.
#
# Until the first issuance succeeds, the NixOS module serves a self-signed
# placeholder (acme-selfsigned-*), so nginx starts regardless; Cloudflare answers
# 526 for those few minutes.
#
# Exposure:
#   80, 443  bound on all interfaces, both families — the only extra WAN ports.
#            :80 only redirects to HTTPS (`forceSSL`); ACME does not need it.
# Unknown names under the wildcard hit the catch-all vhost, which refuses the
# TLS handshake instead of falling through to whichever vhost nginx saw first.
#
# Upstreams are loopback. Host-local traffic traverses `lo`, which the firewall
# accepts unconditionally, so the source-restricted rules in forgejo.nix /
# ntfy.nix need no entry for the proxy.
{ config, ... }:
let
  domain = "mauderer.work";

  proxy = port: extra: {
    useACMEHost = domain;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
    }
    // extra;
  };

  vhosts = {
    # forgejo.nix. Large bodies for HTTPS pushes and LFS uploads (NixOS's
    # default is 10m; Cloudflare's free plan caps a request at 100 MB anyway).
    "git.${domain}" = proxy 4000 { extraConfig = "client_max_body_size 512m;"; };

    # ntfy.nix. Upstream's recommended nginx settings: subscriptions are
    # long-lived streams, so no buffering and generous timeouts.
    "ntfy.${domain}" = proxy 2586 {
      extraConfig = ''
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_connect_timeout 3m;
        proxy_send_timeout 3m;
        proxy_read_timeout 3m;
        client_max_body_size 0;
      '';
    };

    # greenhouse.nix: its own loopback-only nginx vhost (SPA + /api).
    "greenhouse.${domain}" = proxy 8080 { };
  };
in
{
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  security.acme = {
    acceptTerms = true;
    defaults.email = "daniel090798@gmail.com";
    certs.${domain} = {
      domain = "*.${domain}";
      extraDomainNames = [ domain ];
      dnsProvider = "cloudflare";
      # Handed over via LoadCredential, so the root-owned sops file works as is.
      credentialFiles.CF_DNS_API_TOKEN_FILE = config.sops.secrets.cloudflare-api-token.path;
      group = config.services.nginx.group;
    };
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;

    virtualHosts = vhosts // {
      catch-all = {
        default = true;
        rejectSSL = true;
        locations."/".return = "444";
      };
    };
  };
}
