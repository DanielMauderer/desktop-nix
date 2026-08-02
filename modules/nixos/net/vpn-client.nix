# A second WireGuard tunnel (`wg1`), alongside the home-server client on `wg0`.
# Config comes from a provider-issued wg.conf: the non-secret fields become
# options below, the `PrivateKey` line becomes a per-host sops secret.
# `enable`-gated so an un-enrolled host (no committed key) still builds under CI.
{ config, lib, ... }:
let
  cfg = config.services.vpnClient;
in
{
  options.services.vpnClient = {
    enable = lib.mkEnableOption "second WireGuard tunnel (wg1) from a provider wg.conf";

    address = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      example = [ "10.2.0.2/32" ];
      description = "The `Address` line of wg.conf. Per device — no two peers share it.";
    };

    endpoint = lib.mkOption {
      type = lib.types.str;
      example = "vpn.example.net:51820";
      description = "The peer's `Endpoint` (host:port) from wg.conf.";
    };

    publicKey = lib.mkOption {
      type = lib.types.str;
      example = "AAAA…=";
      description = "The peer's `PublicKey` from wg.conf (non-secret).";
    };

    allowedIPs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "0.0.0.0/0"
        "::/0"
      ];
      description = ''
        The peer's `AllowedIPs`. The default is a full tunnel; wg0's
        `10.100.0.0/24` is more specific, so the home-server tunnel keeps
        working alongside it.
      '';
    };

    dns = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        The `DNS` line of wg.conf, or empty to keep the system resolver.
        Setting it makes wg-quick rewrite `/etc/resolv.conf`, which fights
        systemd-resolved — leave empty unless the tunnel actually needs it.
      '';
    };

    presharedKey = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        The wg.conf has a `PresharedKey` line. The value itself is a secret, so
        it lives in `secrets/<host>/vpn.yaml` under `vpn-wg-psk` rather than in
        this option — set this to true once that key is enrolled. A PSK
        configured on only one side makes the handshake fail outright.
      '';
    };

    autostart = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Bring wg1 up at boot. Off by default: a full tunnel is usually an
        on-demand thing — `systemctl start wg-quick-wg1` when you want it.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # sopsFile derived from the hostname so the module needs no per-host wiring.
    # Kept out of wireguard.yaml so a fumbled `sops edit` can't break wg0.
    sops.secrets = {
      vpn-wg-key = {
        sopsFile = ../../../secrets + "/${config.networking.hostName}/vpn.yaml";
      };
    }
    // lib.optionalAttrs cfg.presharedKey {
      vpn-wg-psk = {
        sopsFile = ../../../secrets + "/${config.networking.hostName}/vpn.yaml";
      };
    };

    networking.wg-quick.interfaces.wg1 = {
      inherit (cfg) address autostart dns;
      privateKeyFile = config.sops.secrets.vpn-wg-key.path;
      peers = [
        (
          {
            inherit (cfg) endpoint publicKey allowedIPs;
            persistentKeepalive = 25;
          }
          // lib.optionalAttrs cfg.presharedKey {
            presharedKeyFile = config.sops.secrets.vpn-wg-psk.path;
          }
        )
      ];
    };
  };
}
