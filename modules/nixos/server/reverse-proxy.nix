# Public reverse proxy for the home-server, run as the Nginx Proxy Manager (NPM)
# container. Let's Encrypt certs and proxy hosts are managed through NPM's web UI
# (HTTP-01 challenge over :80); Nix owns the container, its ports and its volumes.
#
# Exposure:
#   80, 443  published on all interfaces — the public reverse proxy plus the
#            HTTP-01 ACME challenge path. These are the only extra WAN ports.
#   81       the admin UI, published ONLY on the wg0 VPN address (10.100.0.1).
#
# Why bind :81 to the VPN address rather than only firewalling it: podman
# publishes container ports via DNAT in the forward path, which bypasses the
# nixos-fw input chain that `allowedTCPPorts` rules live in — a port published on
# 0.0.0.0 is reachable from the WAN regardless of the firewall. Binding the admin
# publish to 10.100.0.1 is what actually keeps it VPN-only; the wg0 firewall rule
# below is kept as defence-in-depth / intent.
#
# DNS: `*.mauderer.work` is a *proxied* (orange-cloud) AAAA record kept current by
# cloudflare-ddns.nix, so HTTP-01 challenges traverse the Cloudflare edge rather
# than hitting :80 directly. Cloudflare passes /.well-known/acme-challenge
# through, so this works — but DNS-01 is the robust path for a proxied wildcard.
# For any host you do want to validate directly, set that record DNS-only
# (grey-cloud) pointing at the WAN address with :80 reachable.
_: {
  # Public HTTP/HTTPS for the reverse proxy (and HTTP-01 challenges on :80).
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  # NPM admin UI: VPN-only, never the WAN (the publish bind above enforces this).
  networking.firewall.interfaces.wg0.allowedTCPPorts = [ 81 ];

  virtualisation.oci-containers.containers.npm = {
    image = "jc21/nginx-proxy-manager:2.15.1";
    ports = [
      "80:80" # WAN HTTP + HTTP-01 ACME
      "443:443" # WAN HTTPS
      "10.100.0.1:81:81" # admin UI, VPN address only
    ];
    volumes = [
      "/hdd_pool_1/services/npm/data:/data"
      "/hdd_pool_1/services/npm/letsencrypt:/etc/letsencrypt"
    ];
    # Anti-escape hardening: block in-container privilege escalation. By omission
    # there is also no --privileged, no host device passthrough and — crucially —
    # no docker/podman socket mount (a container with the management socket is
    # effectively root on the host). Only the two data volumes are bind-mounted.
    extraOptions = [ "--security-opt=no-new-privileges" ];
  };

  # Bind-mount sources for the container. Podman does not create them: a missing
  # path makes it exit 125 ("statfs ...: no such file or directory"), which in
  # turn fails the whole nixos-rebuild switch.
  #
  # systemd.tmpfiles did not do the job: with the rules present in
  # /etc/tmpfiles.d/00-nixos.conf and the pool mounted, a switch still left
  # data/ and letsencrypt/ absent. This unit sits inside podman-npm's own
  # dependency chain, which already requires zfs-mount.service, so it cannot run
  # before the pool is mounted or after the container is started.
  systemd.services.npm-data-dirs = {
    requires = [ "zfs-mount.service" ];
    after = [ "zfs-mount.service" ];
    before = [ "podman-npm.service" ];
    requiredBy = [ "podman-npm.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    # 0755 on the shared `services` parent, not 0750: forgejo-dump-dirs and
    # paperless-data-dirs create sibling directories there with no ordering
    # between the three units, so all of them must leave the parent in the same
    # state. Traversable-but-not-writable lets each unprivileged service reach
    # its own subtree; the subtrees themselves stay 0750.
    script = ''
      mkdir -p /hdd_pool_1/services/npm/data /hdd_pool_1/services/npm/letsencrypt
      chmod 0755 /hdd_pool_1 /hdd_pool_1/services
      chmod 0750 /hdd_pool_1/services/npm
    '';
  };

  # The admin port binds to the wg0 address and the data lives on the ZFS pool, so
  # start the container only once the VPN interface is up and the pool is mounted.
  systemd.services.podman-npm = {
    after = [
      "wireguard-wg0.service"
      "zfs-mount.service"
    ];
    requires = [
      "wireguard-wg0.service"
      "zfs-mount.service"
    ];
  };
}
