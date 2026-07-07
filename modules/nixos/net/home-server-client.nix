# WireGuard client + NFS auto-mount for the home-server. `enable`-gated so an
# un-enrolled host (no committed sops key) still builds under keyless CI.
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

    # Same for every client, so kept here as defaults (fill once, non-secret).
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
    # sopsFile derived from the hostname so the module needs no per-host wiring.
    sops.secrets.home-server-wg-key = {
      sopsFile = ../../../secrets + "/${config.networking.hostName}/wireguard.yaml";
    };

    # Split-tunnel: allowedIPs is only the VPN subnet, so this reaches the
    # server's services without becoming a default route or hijacking DNS.
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

    # Pin the server's host key so `ssh home-server` has no TOFU prompt.
    programs.ssh.knownHosts."home-server" = {
      hostNames = [
        "10.100.0.1"
        "home-server"
      ];
      publicKey = cfg.serverHostKey;
    };

    # `x-systemd.automount` + `noauto`: mounts on first access, never blocks boot
    # when the server is unreachable; idle-timeout unmounts after 10 min.
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
