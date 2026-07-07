<<<<<<< HEAD
_: {
  # Key is provisioned at install time (`umask 077; wg genkey > /etc/wireguard/
  # wg0.key`), not via sops, so keyless CI still builds.
=======
# WireGuard VPN server (wg0).
#
# The server terminates the tunnel and is the gateway for the 10.100.0.0/24
# VPN subnet (the server itself is 10.100.0.1). SSH and the NFS share are
# reachable only across this interface (see ssh.nix / nfs.nix).
#
# Key source (DECISIONS 035/049): the private key is a `sops.secrets` entry
# decrypted at *activation* time from secrets/home-server/wireguard.yaml, using
# the host's SSH-host-key-derived age identity. Nothing is decrypted at eval or
# build time, so `nix flake check` / the CI toplevel build stay keyless — the
# encrypted file just has to exist (it is committed). The host's age key is
# pre-seeded before the nixos-anywhere install (hosts/home-server/INSTALL.md), so
# this decrypts on first boot. Each client's PUBLIC key (non-secret, safe to
# commit) goes in `peers`.
{ config, ... }:
{
  # Server WireGuard private key, decrypted to /run/secrets at activation.
  sops.secrets.wg-server-key = {
    sopsFile = ../../../secrets/home-server/wireguard.yaml;
  };

>>>>>>> b931bdd (discord and homeserver strategy)
  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.100.0.1/24" ];
    listenPort = 51820;
    privateKeyFile = config.sops.secrets.wg-server-key.path;

<<<<<<< HEAD
    # One /32 block per client. Paste each client's PUBLIC key and uncomment.
=======
    # One block per client (the client half is modules/nixos/net; each host
    # enrolls per its INSTALL.md). allowedIPs is the address routed to that peer
    # inside the tunnel — a /32 per client for a hub-and-spoke layout.
>>>>>>> b931bdd (discord and homeserver strategy)
    peers = [
      {
        # desktop
        publicKey = "q8YwGgYKdESpiII74Hyxwvi3t3vYKPB985VcSDKUxA4=";
        allowedIPs = [ "10.100.0.2/32" ];
      }
      {
        # private-laptop
        publicKey = "e0AoY1JO+IHL3GEms8gYeVwZv8HGjcZQGLBeanDNeRY=";
        allowedIPs = [ "10.100.0.3/32" ];
      }
    ];
  };

  networking.firewall.allowedUDPPorts = [ 51820 ];

  # Uncomment (plus forward/NAT rules) to let VPN peers route on to the LAN.
  # boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
}
