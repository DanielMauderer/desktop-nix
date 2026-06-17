# Server module — the home-server's service stack (DECISIONS 049).
# Imported only by hosts/home-server. Everything here is deliberately absent
# from the desktop/workstation `base`: a WAN-facing firewall (port 80/443), a
# WireGuard VPN server, VPN-only SSH, a ZFS data pool, an NFS export and the
# container runtime groundwork for the user's docker-compose / Ansible services.
_: {
  imports = [
    ./ssh.nix
    ./wireguard.nix
    ./reverse-proxy.nix
    ./containers.nix
    ./zfs.nix
    ./nfs.nix
  ];
}
