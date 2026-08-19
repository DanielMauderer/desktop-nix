# WireGuard client + NFS auto-mount for the home-server. `enable`-gated so an
# un-enrolled host (no committed sops key) still builds under keyless CI.
#
# ## Why the endpoint is re-resolved on a timer
#
# WireGuard resolves `Endpoint` exactly once, when the interface comes up, and
# then keeps sending to that address forever — the kernel side holds an address,
# not a name. The server sits behind a dynamic WAN address on both families
# (`server/cloudflare-ddns.nix` republishes `vpn.mauderer.work` every five
# minutes), so every ISP reconnect leaves this host handshaking into an address
# that now belongs to somebody else. Nothing recovers from that on its own: the
# tunnel is not "down" in a way wg-quick notices, it is simply silent until the
# interface is restarted by hand, which is the shape "the VPN works until it
# doesn't" usually takes.
#
# The timer below is the standard fix (the `reresolve-dns` recipe from
# wireguard-tools' contrib, written out here rather than vendored): if the peer's
# last handshake is older than the ~150 s a healthy `persistentKeepalive = 25`
# tunnel ever goes without one, re-resolve the name and re-set the endpoint. The
# staleness guard is the load-bearing part — re-setting the endpoint of a
# *healthy* peer would clobber the address WireGuard learned from the peer's own
# roaming, which is the one thing this must not break.
#
# It is added only when `endpoint` is a hostname. A host that tunnels straight to
# a literal address (the desktop, which is on the server's LAN) has nothing to
# re-resolve and gets no unit at all.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.homeServerClient;

  # An IPv4 endpoint is `1.2.3.4:51820`, an IPv6 one `[2001:db8::1]:51820`.
  # Anything else names a host, and a name is the thing that can start pointing
  # somewhere else while the interface stays up. `builtins.match` is POSIX ERE,
  # where a backslash-escaped `[` is not a literal bracket — hence `[[]`/`[]]`.
  endpointIsName =
    builtins.match "[0-9]+(\\.[0-9]+){3}:[0-9]+" cfg.endpoint == null
    && builtins.match "[[][0-9a-fA-F:]+[]]:[0-9]+" cfg.endpoint == null;

  # Long enough that a healthy tunnel never trips it: with
  # `persistentKeepalive = 25` WireGuard renews the handshake about every two
  # minutes, so anything past 150 s means the far end is not answering.
  staleAfter = 150;
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
      # NOTE: WireGuard is UDP/51820. Cloudflare's proxy (orange-cloud) only
      # handles HTTP/S, so vpn.mauderer.work MUST be a DNS-only (grey-cloud)
      # record pointing at the WAN IP, or the handshake never reaches the server.
      # It carries both an A and an AAAA (server/cloudflare-ddns.nix), so this
      # resolves on an IPv4-only network too; the router has to forward inbound
      # UDP 51820 on both families for that to be worth anything.
      default = "vpn.mauderer.work:51820";
      description = ''
        Public host:port of the home-server's WireGuard endpoint. A hostname
        here also gets the re-resolve timer described in this file's header; an
        address literal does not, since there is nothing to re-resolve.
      '';
    };

    serverPublicKey = lib.mkOption {
      type = lib.types.str;
      default = "qu9Ov4yxMb0+abHf6A9JMKYbEqEMVwoJ5JU5dEHtlz8=";
      description = "The home-server's WireGuard public key (non-secret).";
    };

    serverHostKey = lib.mkOption {
      type = lib.types.str;
      default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIycBJJ+ZA+Ln4bkHzpc2sDbyGV3lcvLHvi1dfW3Y/3D";
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

    # Re-resolve the endpoint name when the tunnel has gone quiet. See the
    # header; only defined when `endpoint` is a name rather than a literal.
    systemd.services.wg0-reresolve = lib.mkIf endpointIsName {
      description = "Re-resolve the home-server WireGuard endpoint";
      after = [ "wg-quick-wg0.service" ];
      path = with pkgs; [
        wireguard-tools
        gawk
        coreutils
      ];
      serviceConfig.Type = "oneshot";
      script = ''
        peer=${lib.escapeShellArg cfg.serverPublicKey}

        # wg-quick-wg0 is `wantedBy` multi-user.target, not required by it, so
        # the interface legitimately may not exist (failed key, tunnel stopped).
        # That is not this unit's problem to report every minute.
        wg show wg0 >/dev/null 2>&1 || exit 0

        handshake=$(wg show wg0 latest-handshakes | awk -v p="$peer" '$1 == p { print $2 }')
        [ -n "$handshake" ] || exit 0

        # 0 is "never handshaked since the interface came up" — which is exactly
        # the case where the name was resolved once, at boot, and may already
        # have been wrong then. Anything recent means the tunnel is working and
        # the endpoint must be left alone: WireGuard may have learned a better
        # one from the peer's own roaming, and overwriting it would break a
        # working tunnel to fix nothing.
        if [ "$handshake" -ne 0 ] && [ $(( $(date +%s) - handshake )) -lt ${toString staleAfter} ]; then
          exit 0
        fi

        # `wg set … endpoint host:port` does the lookup itself. A failure here is
        # almost always "this machine has no working network right now", which on
        # a laptop is routine — log it and exit 0 rather than leaving a failed
        # unit (and an alert-worthy journal entry) behind every single minute.
        if ! wg set wg0 peer "$peer" endpoint ${lib.escapeShellArg cfg.endpoint}; then
          echo "wg0: could not resolve ${cfg.endpoint}; will retry on the next tick"
        fi
      '';
    };

    systemd.timers.wg0-reresolve = lib.mkIf endpointIsName {
      description = "Re-resolve the home-server WireGuard endpoint periodically";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = "1min";
        # The check is a couple of `wg show` calls and exits early while the
        # tunnel is healthy, so a one-minute tick costs nothing and bounds how
        # long the tunnel stays pointed at the server's old address.
        AccuracySec = "10s";
      };
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
