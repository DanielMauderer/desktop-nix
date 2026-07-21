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
# For HTTP-01 to succeed the proxied domain's DNS A record must be DNS-only
# (grey-cloud in Cloudflare) pointing at the WAN IP, with :80 reachable.
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

  # The admin port binds to the wg0 address and the data lives on the ZFS pool, so
  # start the container only once the VPN interface is up and the pool is mounted
  # (podman creates the bind-mount source dirs, which must land on the pool).
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
