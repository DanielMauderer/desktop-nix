# Self-hosted forge: native `services.forgejo`, SQLite-backed, served publicly as
# https://git.mauderer.work through the Nginx Proxy Manager container. GitHub is
# demoted to a push-mirror target (see the per-repo step in INSTALL.md), so this
# box — not GitHub — is the source of truth for the repositories it hosts.
#
# Exposure (no new WAN ports; the WAN surface stays UDP 51820 + TCP 80/443):
#   3000  HTTP, admitted only from the podman bridge subnet, because the NPM
#         container is what proxies it. TLS terminates in NPM, so this speaks
#         plain HTTP and must never reach the WAN.
#   2222  Forgejo's built-in Go SSH server for git clone/push, admitted only from
#         the LAN and the wg0 VPN. Host sshd (:22, VPN-only) is untouched.
#
# Source-restricted nftables rules are used rather than `allowedTCPPorts` for the
# same reason nfs.nix does it: those ports must never be globally open. Note this
# is a *host* service, not a published container port, so — unlike NPM's admin UI
# — the input chain really does apply here.
#
# Storage: state stays on the SSD root at the module default /var/lib/forgejo.
# SQLite and git object churn are latency-bound, and every path under `stateDir`
# gets a systemd.tmpfiles rule, which does not work for the ZFS pool (tmpfiles
# runs before zfs-mount.service — see the note in reverse-proxy.nix). Durability
# instead comes from the nightly `forgejo dump` landing on the redundant pool.
{ config, lib, ... }:
let
  # Keep in sync with nfs.nix — same LAN, same VPN subnet as wireguard.nix.
  lanSubnet = "192.168.178.0/24";
  vpnSubnet = "10.100.0.0/24";

  # podman's default network, from virtualisation.podman.defaultNetwork: bridge
  # podman0, gateway 10.88.0.1. The NPM container lives here, and so do Actions
  # job containers (forgejo-runner.nix pins them to the same network).
  podmanSubnet = "10.88.0.0/16";

  domain = "git.mauderer.work";
  httpPort = 3000;
  sshPort = 2222;
in
{
  services.forgejo = {
    enable = true;
    database.type = "sqlite3";
    lfs.enable = true;

    # Nightly `forgejo dump` onto the mirrored ZFS pool: repositories, the SQLite
    # database, LFS objects and the config in one archive. This is the only copy
    # of the forge that survives losing the SSD.
    dump = {
      enable = true;
      backupDir = "/hdd_pool_1/services/forgejo/dump";
      type = "tar.zst";
      age = "8w";
    };

    settings = {
      server = {
        DOMAIN = domain;
        ROOT_URL = "https://${domain}/";
        # TLS terminates at NPM; Forgejo itself speaks plain HTTP on the bridge.
        PROTOCOL = "http";
        HTTP_ADDR = "0.0.0.0";
        HTTP_PORT = httpPort;

        # Forgejo's own SSH server rather than the host's: it keeps git keys in
        # Forgejo's database instead of a shared authorized_keys, and leaves :22
        # exclusively for admin login over the VPN.
        START_SSH_SERVER = true;
        SSH_LISTEN_HOST = "0.0.0.0";
        SSH_LISTEN_PORT = sshPort;
        SSH_PORT = sshPort; # the port shown in clone URLs
        SSH_DOMAIN = domain;

        LANDING_PAGE = "explore";
        # Serve assets locally instead of from a third-party CDN.
        OFFLINE_MODE = true;
      };

      # Single-user forge: accounts are created by the admin, never self-served.
      # This is also what makes the runner's podman access acceptable — see the
      # security note in forgejo-runner.nix.
      service.DISABLE_REGISTRATION = true;

      session.COOKIE_SECURE = true;

      actions = {
        ENABLED = true;
        # Resolve bare `uses: actions/checkout@v4` against github.com rather than
        # code.forgejo.org, so workflows migrated from GitHub keep working.
        DEFAULT_ACTIONS_URL = "github";
      };

      # Push mirrors (the GitHub backup) are configured per repository in the UI.
      mirror.ENABLED = true;

      repository.DEFAULT_BRANCH = "main";
    };
  };

  # `extraInputRules` exists only on the nftables backend and is silently ignored
  # under iptables — which would leave both ports unreachable rather than merely
  # unrestricted. core/hardening.nix already turns nftables on for every host;
  # this default keeps the module honest on its own (the VM test node relies on
  # it) without overriding a host that sets it explicitly.
  networking.nftables.enable = lib.mkDefault true;

  # Neither port is ever globally open. :3000 is admitted from the podman bridge
  # (that's the reverse proxy, the normal path) and from the VPN, so the admin UI
  # is reachable at http://10.100.0.1:3000 for the bootstrap steps that need it —
  # creating the first admin and minting the runner token — and stays usable if
  # DNS or the cert ever breaks. That path is plain HTTP over WireGuard, the same
  # posture as NPM's own admin UI on :81. :2222 is git-over-SSH, LAN and VPN only.
  networking.firewall.extraInputRules = ''
    ip saddr { ${podmanSubnet}, ${vpnSubnet} } tcp dport ${toString httpPort} accept
    ip saddr { ${lanSubnet}, ${vpnSubnet} } tcp dport ${toString sshPort} accept
  '';

  # `dump.backupDir` lives on the ZFS pool, and the module declares it via
  # systemd.tmpfiles, which runs too early to see the mount. Same fix as
  # npm-data-dirs: a oneshot inside the consumer's own dependency chain, so it
  # cannot run before the pool is mounted or after the dump has started. The
  # requiredBy/before pair also orders forgejo-dump.service itself after the
  # mount, so no extra ordering on that unit is needed.
  #
  # Gated on dump.enable so a node that turns dumps off (the VM test) doesn't
  # end up referencing a unit that isn't there.
  systemd.services.forgejo-dump-dirs = lib.mkIf config.services.forgejo.dump.enable {
    requires = [ "zfs-mount.service" ];
    after = [ "zfs-mount.service" ];
    before = [ "forgejo-dump.service" ];
    requiredBy = [ "forgejo-dump.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    # Unlike NPM — a rootful container, which ignores these bits — forgejo runs
    # unprivileged, so it needs search (x) on *every* parent to reach the dump
    # directory. `mkdir -p` would leave the parents root:root 0750, which locks
    # it out. Group-ownership is the durable fix: npm-data-dirs also chmods the
    # shared `services` dir and the two units have no ordering between them, so
    # a mode tweak there could be undone, whereas nothing chowns it.
    script = ''
      mkdir -p /hdd_pool_1/services/forgejo/dump
      chown root:forgejo /hdd_pool_1/services /hdd_pool_1/services/forgejo
      chown forgejo:forgejo /hdd_pool_1/services/forgejo/dump
      chmod 0750 /hdd_pool_1/services /hdd_pool_1/services/forgejo /hdd_pool_1/services/forgejo/dump
    '';
  };
}
