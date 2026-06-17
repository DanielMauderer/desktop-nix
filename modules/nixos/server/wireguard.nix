# WireGuard VPN server (wg0).
#
# The server terminates the tunnel and is the gateway for the 10.100.0.0/24
# VPN subnet (the server itself is 10.100.0.1). SSH and the NFS share are
# reachable only across this interface (see ssh.nix / nfs.nix).
#
# Keyless-CI note (mirrors DECISIONS 035): the private key is read from a path
# *provisioned at install time*, NOT a `sops.secrets` entry pointing at a
# not-yet-existing encrypted file — so `nix flake check` / the CI toplevel build
# stay keyless (nothing is decrypted at eval or build time). Generate it once on
# the box with `umask 077; wg genkey > /etc/wireguard/wg0.key` (see the runbook),
# then add each client's PUBLIC key (non-secret, safe to commit) to `peers`. A
# later migration to sops can swap `privateKeyFile` for the decrypted secret path
# once the host's age key is enrolled (.sops.yaml already scaffolds it).
_: {
  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.100.0.1/24" ];
    listenPort = 51820;
    privateKeyFile = "/etc/wireguard/wg0.key";

    # Add one block per client. allowedIPs is the address(es) routed to that
    # peer inside the tunnel — a /32 per client for a hub-and-spoke layout.
    peers = [
      # {
      #   publicKey = "<client public key>";
      #   allowedIPs = [ "10.100.0.2/32" ];
      # }
    ];
  };

  # The only WAN-facing port the VPN needs. UDP, so it is invisible to TCP
  # port scans and unaffected by the SSH/NFS interface-scoped rules.
  networking.firewall.allowedUDPPorts = [ 51820 ];

  # Uncomment to let VPN peers route on to the LAN / out through the server.
  # Not needed just to reach services ON the server (SSH, NFS, the proxy);
  # enabling it also means adding the matching forward/NAT rules.
  # boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
}
