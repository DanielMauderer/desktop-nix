# The single reader for metrics.nix and logs.nix: native `services.grafana`,
# SQLite-backed, reachable only across the wg0 VPN.
#
# Exposure (no new WAN ports; the WAN surface stays UDP 51820 + TCP 80/443):
#   3030  HTTP, admitted only on the wg0 interface — the same posture as host
#         sshd in ssh.nix and the archive in paperless.nix. Deliberately NOT
#         proxied through NPM: there is no public hostname for it, so Grafana
#         never answers on the WAN at all. Do not add a proxy host for it in the
#         NPM UI — that would silently undo the VPN-only property.
#
# The port is left out of `allowedTCPPorts` entirely and admitted per-interface,
# so the "WAN TCP surface is exactly 80/443" assertion in flake.nix keeps
# holding. This is a *host* service, not a published container port, so the
# nixos-fw input chain really does apply here (contrast reverse-proxy.nix, where
# podman's DNAT bypasses it and the bind address is what enforces the VPN).
#
# Why 3030 and not Grafana's default 3000: 3000-3010 is already spoken for on
# this box — the same constraint that pushed Paperless off it, recorded as an
# assertion in flake.nix.
#
# Storage: the SQLite database lives on the mirrored ZFS pool. It is small, but
# it holds every hand-built dashboard, alert rule and API key — the one part of
# the observability stack that is not derived from something else and cannot be
# rebuilt by waiting. Datasources are provisioned from Nix instead, so a fresh
# install comes up already wired to Prometheus and Loki; dashboards are imported
# in the UI, the same division of labour as NPM's UI-managed proxy hosts.
{ config, ... }:
let
  dataDir = "/hdd_pool_1/services/grafana";

  httpPort = 3030;

  # The VPN address the UI is actually reached on. Grafana builds redirect and
  # asset URLs from `root_url`, so this has to match or logins bounce to a host
  # that does not resolve — the same trap as Paperless' PAPERLESS_URL.
  vpnAddress = "10.100.0.1";

  # Keep in sync with metrics.nix and logs.nix.
  prometheusUrl = "http://127.0.0.1:9090";
  lokiUrl = "http://127.0.0.1:3100";
in
{
  services.grafana = {
    enable = true;

    inherit dataDir;

    settings = {
      server = {
        protocol = "http";
        # Listen on all interfaces and let the per-interface firewall rule below
        # restrict it to the VPN — the same arrangement as host sshd and
        # Paperless. Binding directly to the wg0 address would additionally
        # couple this unit's startup to wireguard-wg0.service, which is only
        # worth it for container publishes the firewall cannot see.
        http_addr = "0.0.0.0";
        http_port = httpPort;
        domain = vpnAddress;
        root_url = "http://${vpnAddress}:${toString httpPort}/";
      };

      security = {
        admin_user = "admin";
        # Read from the sops-decrypted file at startup rather than baked into
        # the ini in the world-readable Nix store. Grafana expands `$__file{}`
        # for any setting.
        admin_password = "$__file{${config.sops.secrets.grafana-admin-password.path}}";
        # Served as plain HTTP over WireGuard, so the session cookie must not be
        # marked Secure or no browser will send it back. This is the same
        # posture as NPM's admin UI on :81 and Forgejo's :4000 bootstrap path —
        # acceptable because the transport underneath is the VPN.
        cookie_secure = false;
        disable_gravatar = true;
      };

      # Single-admin instance: accounts are created by the admin, never
      # self-served, and there is no anonymous read.
      users.allow_sign_up = false;
      "auth.anonymous".enabled = false;

      # No phone-home, and no "a new version is available" nag on a box whose
      # packages come from the flake lock anyway.
      analytics = {
        reporting_enabled = false;
        check_for_updates = false;
      };
    };

    # Datasources come from Nix, so a rebuilt server is immediately useful; both
    # are reached over loopback (see the exposure notes in the sibling modules).
    # Provisioned datasources are read-only in the UI by design — edit them
    # here.
    provision = {
      enable = true;
      datasources.settings = {
        apiVersion = 1;
        datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            uid = "prometheus";
            access = "proxy";
            url = prometheusUrl;
            isDefault = true;
          }
          {
            name = "Loki";
            type = "loki";
            uid = "loki";
            access = "proxy";
            url = lokiUrl;
          }
        ];
      };
    };
  };

  # Admin password, decrypted to /run/secrets at activation (keyless CI: the
  # encrypted file just has to exist). The file must hold the BARE password.
  #
  # `owner` matters here in a way it does not for the other secrets on this
  # host: Grafana opens this file itself, as the unprivileged grafana user,
  # rather than having systemd hand it in as a credential.
  sops.secrets.grafana-admin-password = {
    sopsFile = ../../../secrets/home-server/grafana.yaml;
    owner = "grafana";
    group = "grafana";
    mode = "0400";
  };

  # Admit the UI only on the VPN interface, never the WAN. Same pattern as
  # ssh.nix and paperless.nix; the port is never added to `allowedTCPPorts`.
  networking.firewall.interfaces.wg0.allowedTCPPorts = [ httpPort ];

  # `dataDir` is on the ZFS pool, and upstream declares it through
  # systemd.tmpfiles, which runs before zfs-mount.service. Same fix as
  # npm-data-dirs, forgejo-dump-dirs, paperless-data-dirs and loki-data-dirs: a
  # oneshot inside grafana.service's own dependency chain, so it cannot run
  # before the pool is mounted. The requiredBy/before pair also orders
  # grafana.service after the mount, so that unit needs no extra ordering.
  #
  # The early tmpfiles run still creates a shadow tree under an unmounted
  # /hdd_pool_1; it is hidden by the mount and harmless.
  systemd.services.grafana-data-dirs = {
    requires = [ "zfs-mount.service" ];
    after = [ "zfs-mount.service" ];
    before = [ "grafana.service" ];
    requiredBy = [ "grafana.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    # /hdd_pool_1/services is shared with npm, forgejo, paperless and loki, and
    # none of those oneshots are ordered against each other — so all of them
    # must leave the parent as root:root 0755 or the last one to run locks the
    # others out of their own subtree. See the note in server/README.md.
    script = ''
      mkdir -p ${dataDir}
      chmod 0755 /hdd_pool_1/services
      chown grafana:grafana ${dataDir}
      chmod 0750 ${dataDir}
    '';
  };
}
