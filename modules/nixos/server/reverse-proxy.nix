# Public reverse proxy for the home-server, run as the Nginx Proxy Manager (NPM)
# container. Let's Encrypt certs and proxy hosts are managed through NPM's web UI
# (DNS-01 challenge via Cloudflare — see the DNS note below); Nix owns the
# container, its network model and its volumes.
#
# Networking: the container runs in the HOST network namespace (`--network=host`),
# not with published ports. This is not a convenience — the box is IPv6-only
# inbound (DS-Lite; see cloudflare-ddns.nix), and podman's port publishing does
# not reach it. `ports = [ "80:80" ]` becomes an nftables DNAT rule in the `ip`
# family only; with no IPv6-enabled podman network there is no `ip6` counterpart.
# Measured from the LAN: `10.100.0.1:80` answered 200 while the host's global
# IPv6 refused the connection instantly. Since the only public record is an AAAA,
# that meant Let's Encrypt's HTTP-01 fetch was refused outright ("Error getting
# validation data") and Cloudflare had no origin to proxy to.
# In the host netns nginx binds :80/:443 itself, on both families, with no DNAT.
#
# Exposure:
#   80, 443  bound on all interfaces — the public reverse proxy plus the
#            HTTP-01 ACME challenge path. These are the only extra WAN ports.
#   81       the admin UI, VPN-only.
#   Anything NPM binds internally (its Node backend) is no longer confined to a
#   container netns and lands on the host. None of it is in any firewall rule, so
#   the input chain drops it everywhere except loopback — check `ss -tlnp` after
#   a version bump if a new listener appears, and for a port conflict with the
#   native services on this box.
#
# What keeps :81 off the WAN is now the firewall, and that inverts the rationale
# this file used to carry. With published ports, podman's DNAT sits in the forward
# path and bypasses the nixos-fw input chain, so `allowedTCPPorts` could not
# protect a container port at all and the `10.100.0.1:81:81` publish bind was the
# only real control. With host networking there is no DNAT: nginx is an ordinary
# host listener, so the input chain applies to it exactly as it does to sshd, and
# the wg0-only rule below is the enforcement rather than a statement of intent.
#
# Upstreams must be addressed as 127.0.0.1 in NPM's UI, not as the podman bridge
# gateway (10.88.0.1). The proxy no longer sits on that bridge, and with no
# container attached to it the interface may not exist at all. Host-local traffic
# traverses `lo`, which the firewall accepts unconditionally, so the
# source-restricted rules in forgejo.nix / ntfy.nix / logs.nix keep admitting the
# proxy without change.
#
# DNS: `*.mauderer.work` is a *proxied* (orange-cloud) AAAA record kept current by
# cloudflare-ddns.nix. Because inbound IPv4 does not exist here, the orange cloud
# is what gives IPv4 visitors any path in at all — grey-cloud is a debugging
# state, not a steady one. Certificates should therefore be issued by **DNS-01**
# (NPM: Certificates → Add → DNS Challenge → Cloudflare), which needs no inbound
# connectivity and is the only option for a wildcard. Note that NPM reads those
# credentials from its own UI-entered state on the pool, *not* from the
# `cloudflare-api-token` sops secret that cloudflare-ddns.nix uses — the same
# token scope (Zone:DNS:Edit + Zone:Zone:Read) works, but it is config outside
# this flake. Port 80 stays open regardless: ACME no longer needs it, the
# HTTP→HTTPS redirect does.
_: {
  # Public HTTP/HTTPS for the reverse proxy (and HTTP-01 challenges on :80).
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  # NPM admin UI: VPN-only, never the WAN. In the host netns nginx binds :81 on
  # all interfaces, so this rule (plus 81's absence from allowedTCPPorts) is what
  # enforces it — see the header on why that is now sufficient.
  networking.firewall.interfaces.wg0.allowedTCPPorts = [ 81 ];

  virtualisation.oci-containers.containers.npm = {
    image = "jc21/nginx-proxy-manager:2.15.1";
    volumes = [
      "/hdd_pool_1/services/npm/data:/data"
      "/hdd_pool_1/services/npm/letsencrypt:/etc/letsencrypt"
    ];
    # Anti-escape hardening: block in-container privilege escalation. By omission
    # there is also no --privileged, no host device passthrough and — crucially —
    # no docker/podman socket mount (a container with the management socket is
    # effectively root on the host). Only the two data volumes are bind-mounted.
    #
    # --network=host gives up network-namespace isolation for this one container
    # (see the header): the mount, PID and user namespaces are untouched, and
    # nothing here was relying on the netns as a boundary — every port it holds
    # was published to the host anyway.
    extraOptions = [
      "--network=host"
      "--security-opt=no-new-privileges"
    ];
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

  # The data lives on the ZFS pool, so start the container only once the pool is
  # mounted. The former wireguard-wg0 dependency is gone with the publish bind
  # that needed it: nothing binds a wg0 address any more, so a VPN that failed to
  # come up would have taken the public proxy down with it for no reason.
  systemd.services.podman-npm = {
    after = [ "zfs-mount.service" ];
    requires = [ "zfs-mount.service" ];
  };
}
