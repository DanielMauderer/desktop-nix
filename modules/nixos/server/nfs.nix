let
  # EDIT to match your network. The VPN subnet matches wireguard.nix.
  lanSubnet = "192.168.1.0/24";
  vpnSubnet = "10.100.0.0/24";
in
{
  services.nfs.server = {
    enable = true;
    exports = ''
      /tank/share ${lanSubnet}(rw,sync,no_subtree_check,root_squash,fsid=0) ${vpnSubnet}(rw,sync,no_subtree_check,root_squash,fsid=0)
    '';
  };

  # Admit NFSv4 (:2049) only from the LAN and VPN source ranges, never the WAN.
  networking.firewall.extraInputRules = ''
    ip saddr { ${lanSubnet}, ${vpnSubnet} } tcp dport 2049 accept
  '';
}
