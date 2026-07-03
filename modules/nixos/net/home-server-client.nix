# home-server VPN client — the counterpart to modules/nixos/server (the box's
# server half). Imported by the personal machines (desktop, private-laptop) so
# `ssh home-server` and the file share Just Work; NEVER by work-laptop, whose
# `wg0` belongs to the corporate VPN, nor by the server itself.
#
# Why an `enable` gate (the one custom option in this repo): the WireGuard
# private key is a per-host sops secret, and a host isn't a peer until it has
# been enrolled (age key in .sops.yaml + committed secrets/<host>/wireguard.yaml
# + its public key added to the server). Until then `enable` stays false and the
# whole `config` block is dropped — so a host can *import* this module, and
# keyless CI can build it, with nothing decrypted at eval time (DECISIONS 035).
# Enrollment runbook: hosts/<host>/INSTALL.md, mirroring the work-laptop one.
{ config, lib, ... }:
let
  cfg = config.services.homeServerClient;
in
{
  options.services.homeServerClient = {
    enable = lib.mkEnableOption "WireGuard client + NFS auto-mount for the home-server";

    address = lib.mkOption {
      type = lib.types.str;
      example = "10.100.0.2/32";
      description = "This peer's wg0 tunnel address (a /32 in the server's 10.100.0.0/24).";
    };

    nfsHost = lib.mkOption {
      type = lib.types.str;
      default = "10.100.0.1";
      description = ''
        Address the NFS share is mounted from. Use the server's LAN IP on an
        always-home host (direct, no crypto on large transfers — the export
        already admits the LAN) and its VPN IP 10.100.0.1 on a roaming laptop.
      '';
    };

    # The next three are the same for every client, so they live here as module
    # defaults (fill once, post-enrollment) rather than being repeated per host.
    # None is secret, all are safe to commit.
    endpoint = lib.mkOption {
      type = lib.types.str;
      default = "REPLACE.WITH.SERVER.DDNS:51820";
      description = "Public host:port of the home-server's WireGuard endpoint.";
    };

    serverPublicKey = lib.mkOption {
      type = lib.types.str;
      default = "REPLACE_WITH_SERVER_WG_PUBLIC_KEY";
      description = "The home-server's WireGuard public key (non-secret).";
    };

    serverHostKey = lib.mkOption {
      type = lib.types.str;
      default = "ssh-ed25519 AAAA_REPLACE_WITH_SERVER_SSH_HOST_KEY";
      description = "The home-server's SSH host public key — pins known-hosts so first login has no TOFU prompt.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Per-host WireGuard private key. sopsFile is derived from the hostname so the
    # module needs no per-host wiring; the file is created at enrollment and this
    # path is only forced when enable = true (so un-enrolled hosts stay keyless).
    sops.secrets.home-server-wg-key = {
      sopsFile = ../../../secrets + "/${config.networking.hostName}/wireguard.yaml";
    };

    # Client side of the tunnel. Split-tunnel: allowedIPs is only the VPN subnet,
    # so this reaches services ON the server (SSH, NFS) without becoming a default
    # route or hijacking DNS. keepalive holds the NAT mapping open behind CGNAT.
    networking.wg-quick.interfaces.wg0 = {
      privateKeyFile = config.sops.secrets.home-server-wg-key.path;
      address = [ cfg.address ];
      peers = [
        {
          inherit (cfg) endpoint;
          publicKey = cfg.serverPublicKey;
          allowedIPs = [ "10.100.0.0/24" ];
          persistentKeepalive = 25;
        }
      ];
    };

    # Pin the server's host key so `ssh home-server` never shows a TOFU prompt.
    programs.ssh.knownHosts."home-server" = {
      hostNames = [
        "10.100.0.1"
        "home-server"
      ];
      publicKey = cfg.serverHostKey;
    };

    # Auto-mount the share. `x-systemd.automount` + `noauto` means it mounts on
    # first access to /mnt/home-server and NEVER blocks boot / systemd when the
    # server is unreachable (the laptop off-network) — the real fix for "auto
    # mount". `idle-timeout` unmounts it again after 10 min idle. The export sets
    # fsid=0, so the NFSv4 pseudo-root is `<host>:/`.
    fileSystems."/mnt/home-server" = {
      device = "${cfg.nfsHost}:/";
      fsType = "nfs";
      options = [
        "x-systemd.automount"
        "noauto"
        "x-systemd.idle-timeout=600"
        "_netdev"
        "nfsvers=4.2"
      ];
    };
  };
}
