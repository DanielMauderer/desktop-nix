# NFS file share, exported from the ZFS data pool (zfs.nix).
#
# Exposed to the LAN and the VPN subnet only — never the WAN. Two layers enforce
# that: the export ACL pins each client CIDR, and the firewall only admits
# :2049 from those same source ranges (an interface-scoped rule won't do here —
# the LAN NIC name isn't known until install, so we match by source address,
# which also covers the wg0 tunnel). NFSv4 is used so a single TCP port (2049)
# is all that needs opening; clients mount `server:/` (fsid=0 pseudo-root).
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

  # Admit NFSv4 (:2049) only from the LAN and VPN source ranges. nftables is on
  # (core/hardening.nix), so these are appended to the input chain, which
  # otherwise default-drops — the WAN never sees the share.
  networking.firewall.extraInputRules = ''
    ip saddr { ${lanSubnet}, ${vpnSubnet} } tcp dport 2049 accept
  '';
}
