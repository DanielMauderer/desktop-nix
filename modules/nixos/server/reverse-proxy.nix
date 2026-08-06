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
# Logs: nginx's access and error logs are written inside the container, into
# `/data/logs` — i.e. onto the pool at /hdd_pool_1/services/npm/data/logs. They
# are the only logs on this box that do not reach journald, so logs.nix tails
# them into Loki; the `npm-data-dirs` script below is what makes them readable
# by an Alloy running under DynamicUser, and logrotate at the bottom is what
# stops them growing without bound.
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
    #
    # `data/logs` is the exception, and it is created here rather than left to
    # nginx so the mode is right *before* the container can write into it.
    # Alloy (logs.nix) tails those files to get NPM's access logs into Loki, and
    # it runs under DynamicUser — so group membership is the only access it can
    # be given. Hence:
    #   - the `npm-logs` group (declared in logs.nix, the reader) owns the
    #     directory and the two levels above it, which stay group r-x: Alloy
    #     traverses and reads, it never writes;
    #   - the setgid bit on `data` and `data/logs`, so a log file nginx creates
    #     for a *new* proxy host inherits the group instead of landing
    #     root:root and staying invisible until the next switch.
    script = ''
      mkdir -p /hdd_pool_1/services/npm/data/logs /hdd_pool_1/services/npm/letsencrypt
      chmod 0755 /hdd_pool_1/services
      chgrp npm-logs /hdd_pool_1/services/npm /hdd_pool_1/services/npm/data \
        /hdd_pool_1/services/npm/data/logs
      chmod 0750 /hdd_pool_1/services/npm
      chmod 2750 /hdd_pool_1/services/npm/data /hdd_pool_1/services/npm/data/logs
      # One-time repair for files nginx created before the setgid bit existed.
      # Scoped to the log files themselves — never a `chown -R` on a pool path,
      # which would re-walk every certificate and database on each boot.
      chgrp npm-logs /hdd_pool_1/services/npm/data/logs/*.log 2>/dev/null || true
      chmod g+r /hdd_pool_1/services/npm/data/logs/*.log 2>/dev/null || true
    '';
  };

  # Nothing rotates these files. They are written by nginx inside the container
  # but live on the host's pool, and the jc21 image has shipped an internal
  # logrotate only intermittently — so rotate them from here, where it is
  # declared and visible. If it turns out the image already does it, this is
  # harmless duplication; check with
  #   podman exec npm ls /etc/logrotate.d /etc/periodic/daily
  #
  # `copytruncate` is not optional: nginx is not ours to signal, so a rename
  # would leave it writing to a deleted inode until the container is restarted
  # and the pool would keep growing invisibly. The trade is a narrow window
  # where lines can be lost, and Alloy re-reading a truncated file from the
  # start (a handful of duplicated lines in Loki). `delaycompress` keeps the
  # most recent rotation uncompressed; Alloy's glob only matches `*.log`, so
  # rotated files are ignored either way.
  services.logrotate.settings."/hdd_pool_1/services/npm/data/logs/*.log" = {
    frequency = "weekly";
    rotate = 8;
    compress = true;
    delaycompress = true;
    missingok = true;
    notifempty = true;
    copytruncate = true;
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
