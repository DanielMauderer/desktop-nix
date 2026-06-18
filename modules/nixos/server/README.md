# server

The home-server's service stack — imported only by `hosts/home-server`.
Everything here is deliberately absent from the workstation `base`.

| File               | Configures                                                   |
|--------------------|-------------------------------------------------------------|
| `ssh.nix`          | OpenSSH re-enabled (key-only, no root), admitted **only on the `wg0` VPN interface** — never the WAN. |
| `wireguard.nix`    | WireGuard **server** (`wg0`, `10.100.0.0/24`, the box is `.1`). Private key provisioned on the box (`/etc/wireguard/wg0.key`); client public keys added to `peers`. UDP 51820 is the only WAN port. |
| `reverse-proxy.nix`| Reverse-proxy groundwork (admin UI scoped to the VPN).      |
| `containers.nix`   | Container-host groundwork for docker-compose / Ansible services. |
| `zfs.nix`          | Imports the pre-existing **ZFS data pool** (`extraPools`, default `tank`) on the RAID LUN; monthly scrub. OS lives on a separate ext4 SSD. |
| `nfs.nix`          | NFSv4 export of `/tank/share` to the LAN + VPN subnets only (edit `lanSubnet`). |

The OS-disk layout is in `hosts/home-server/disk.nix`; the ZFS `hostId` is in
`hosts/home-server/hardware.nix`.
