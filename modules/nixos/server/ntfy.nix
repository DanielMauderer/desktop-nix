# Push notifications: native `services.ntfy-sh`, served publicly as
# https://ntfy.mauderer.work through the Nginx Proxy Manager container. Anything
# on this box (or off it) can reach the phone with a single HTTP POST, so
# scripts, systemd units and Actions jobs get a notification channel without a
# third-party service in the path.
#
# Public rather than VPN-only — the opposite call from paperless.nix — because a
# push notification that only arrives while the phone happens to be on the VPN is
# not a push notification. That is exactly why the instance runs closed: see the
# auth block below.
#
# Exposure (no new WAN ports; the WAN surface stays UDP 51820 + TCP 80/443):
#   2586  HTTP, admitted only from the podman bridge subnet (the NPM container,
#         which proxies it) and from the VPN. TLS terminates in NPM, so this
#         speaks plain HTTP and must never reach the WAN.
#   9686  Prometheus metrics, on a *separate* listener bound to 127.0.0.1 and
#         never firewalled open at all — the same posture as the exporters in
#         metrics.nix. The separation is the point: see the note on
#         `metrics-listen-http` below.
#
# Source-restricted nftables rules again, for the same reason as forgejo.nix: the
# port must never be globally open. `extraInputRules` is a `lines` option, so this
# block merges with Forgejo's — neither module needs to know about the other.
#
# Storage: state stays on the SSD root at the module's StateDirectory,
# /var/lib/ntfy-sh. Unlike Forgejo and Paperless there is no ZFS-pool path and
# hence no zfs-mount ordering oneshot, because there is nothing here worth the
# coupling: the message cache is deliberately transient (12h), and the auth
# database is a handful of users, tokens and ACLs that INSTALL.md can recreate
# from scratch in four commands.
#
# One consequence of upstream's unit worth knowing before you touch the state
# directory: it runs with `DynamicUser = true`, so systemd puts the real
# directory under /var/lib/private/ntfy-sh (root-owned, mode 0700) and leaves
# /var/lib/ntfy-sh as a symlink to it. Admin commands therefore run as **root**,
# which is also what the upstream NixOS test does — `sudo -u ntfy-sh ntfy …`
# cannot traverse /var/lib/private and fails.
{ lib, ... }:
let
  # Keep in sync with forgejo.nix — same VPN subnet as wireguard.nix, same podman
  # bridge (virtualisation.podman.defaultNetwork: podman0, gateway 10.88.0.1)
  # that the NPM container lives on.
  vpnSubnet = "10.100.0.0/24";
  podmanSubnet = "10.88.0.0/16";

  domain = "ntfy.mauderer.work";
  httpPort = 2586;

  # Loopback-only, and never firewalled open — see the metrics note in the
  # settings block. Kept in sync with metrics.nix by hand, the same convention
  # that module uses for its siblings' ports.
  metricsPort = 9686;

  # The module's StateDirectory. Both databases live here.
  stateDir = "/var/lib/ntfy-sh";
in
{
  services.ntfy-sh = {
    enable = true;

    settings = {
      # No trailing slash — ntfy rejects one at startup.
      base-url = "https://${domain}";

      # Listen on all interfaces and let the source-restricted rule below decide
      # who may connect, the same arrangement as Forgejo's :4000.
      listen-http = "0.0.0.0:${toString httpPort}";

      # TLS terminates at NPM, so every request arrives from the bridge gateway.
      # Without this, rate limiting and per-visitor accounting would see one
      # "visitor" (the proxy) for the whole internet.
      behind-proxy = true;

      # The instance is on the public internet, so it is closed by default:
      # unauthenticated requests can neither read nor write any topic, and there
      # is no self-signup. Users, tokens and per-topic ACLs are created with the
      # `ntfy` CLI on the server — see the ntfy section of
      # hosts/home-server/INSTALL.md.
      #
      # That bootstrap is imperative on purpose. ntfy *can* provision users
      # declaratively (`auth-users`/`auth-access`/`auth-tokens`), but each entry
      # carries a bcrypt hash or a live access token, and everything in `settings`
      # is rendered into the world-readable Nix store and committed to this repo —
      # which for a public endpoint is exactly the wrong place. The declarative
      # route needs `services.ntfy-sh.environmentFile` pointed at a sops secret
      # (NTFY_AUTH_USERS=…, NTFY_AUTH_ACCESS=…); worth doing if the account set
      # ever grows, but it buys little for the two or three accounts here, and
      # note that ntfy *deletes* provisioned users that later vanish from the
      # config.
      auth-file = "${stateDir}/user.db";
      auth-default-access = "deny-all";
      enable-signup = false;
      enable-login = true;

      # The cache is what lets a phone that was offline catch up on reconnect; it
      # is not an archive. Anything that must be kept belongs in the service that
      # sent the notification, not here.
      cache-file = "${stateDir}/cache.db";
      cache-duration = "12h";

      # File attachments off, and this has to be said explicitly: the NixOS
      # module mkDefaults `attachment-cache-dir` to a real path under the state
      # directory, so *not* mentioning it here would leave uploads enabled. An
      # empty string is how ntfy disables the feature. A closed endpoint that
      # only accepts notifications is one risk; a file store that anyone holding
      # the publish token can fill up is another, and notifications do not need
      # one — link to a URL with the `Attach` header instead.
      attachment-cache-dir = "";

      # Prometheus metrics on their own loopback listener, scraped by
      # metrics.nix. Deliberately NOT `enable-metrics = true`, which is the
      # obvious option and the wrong one: that serves /metrics from the *main*
      # listener, and the main listener is what NPM proxies to the WAN as
      # ntfy.mauderer.work. `metrics-listen-http` moves the endpoint to a
      # separate socket instead, and ntfy then serves it *only* there — so the
      # public vhost has no /metrics at all and the exposure story stays "the
      # port is bound to 127.0.0.1", the same as every other exporter.
      #
      # Setting both would put it back on the public listener; only this one.
      metrics-listen-http = "127.0.0.1:${toString metricsPort}";

      # iOS only: Apple requires APNs, which a self-hosted instance cannot speak,
      # so the app polls ntfy.sh instead and needs the instance to forward a
      # *hash* of the topic (no message content) upstream. Android's app holds its
      # own WebSocket to this server and needs nothing. Uncomment for an iPhone:
      # upstream-base-url = "https://ntfy.sh";
    };
  };

  # `extraInputRules` exists only on the nftables backend and is silently ignored
  # under iptables — which would leave the port unreachable rather than merely
  # unrestricted. core/hardening.nix already turns nftables on for every host;
  # this default keeps the module honest on its own (the VM test node relies on
  # it) without overriding a host that sets it explicitly. Same as forgejo.nix.
  networking.nftables.enable = lib.mkDefault true;

  # Never globally open. Admitted from the podman bridge (that's the reverse
  # proxy, the normal path) and from the VPN, so http://10.100.0.1:2586 stays
  # reachable for a health check if DNS or the cert ever breaks — the same
  # posture as Forgejo's admin path on :4000.
  networking.firewall.extraInputRules = ''
    ip saddr { ${podmanSubnet}, ${vpnSubnet} } tcp dport ${toString httpPort} accept
  '';
}
