_: {
  # Key is provisioned at install time (`umask 077; wg genkey > /etc/wireguard/
  # wg0.key`), not via sops, so keyless CI still builds.
  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.100.0.1/24" ];
    listenPort = 51820;
    privateKeyFile = "/etc/wireguard/wg0.key";

    # One /32 block per client. Paste each client's PUBLIC key and uncomment.
    peers = [
      # {
      #   publicKey = "<desktop public key>";
      #   allowedIPs = [ "10.100.0.2/32" ];
      # }
      # {
      #   publicKey = "<private-laptop public key>";
      #   allowedIPs = [ "10.100.0.3/32" ];
      # }
    ];
  };

  networking.firewall.allowedUDPPorts = [ 51820 ];

  # Uncomment (plus forward/NAT rules) to let VPN peers route on to the LAN.
  # boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
}
