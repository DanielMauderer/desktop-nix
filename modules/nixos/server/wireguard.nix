{ config, ... }:
{
  # Server private key, decrypted to /run/secrets at activation (keyless CI: the
  # encrypted file just has to exist). Each client's PUBLIC key goes in `peers`.
  sops.secrets.wg-server-key = {
    sopsFile = ../../../secrets/home-server/wireguard.yaml;
  };

  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.100.0.1/24" ];
    listenPort = 51820;
    privateKeyFile = config.sops.secrets.wg-server-key.path;

    # One /32 block per client; allowedIPs is the address routed to that peer.
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
      {
        # phone
        publicKey = "o1LPn3uqdy10BNDF99guNTKGjDQ4palODeH+FHkMORk=";
        allowedIPs = [ "10.100.0.4/32" ];
      }
    ];
  };

  networking.firewall.allowedUDPPorts = [ 51820 ];

  # Uncomment (plus forward/NAT rules) to let VPN peers route on to the LAN.
  # boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
}
