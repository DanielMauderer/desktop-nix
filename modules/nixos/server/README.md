# server

The home-server's service stack — imported only by `hosts/home-server`.
Everything here is deliberately absent from the workstation `base`.

| File               | Configures                                                   |
|--------------------|-------------------------------------------------------------|
| `ssh.nix`          | OpenSSH re-enabled (key-only, no root), admitted **only on the `wg0` VPN interface** — never the WAN. |
| `wireguard.nix`    | WireGuard **server** (`wg0`, `10.100.0.0/24`, the box is `.1`). Private key is a sops secret (`secrets/home-server/wireguard.yaml`), decrypted at activation; client public keys added to `peers`. UDP 51820 is the only WAN port. |
| `reverse-proxy.nix`| **Nginx Proxy Manager** container (LE certs + proxy hosts via its web UI). Public HTTP/HTTPS on `80`/`443`; admin UI published on the VPN address only (`10.100.0.1:81`). Data under `/hdd_pool_1/services/npm`. Certs via HTTP-01. Hardened: no socket mount, `no-new-privileges`. |
| `containers.nix`   | Container-host groundwork for docker-compose / Ansible services. |
| `zfs.nix`          | Imports the pre-existing **ZFS data pool** (`extraPools`, default `tank`) on the RAID LUN; monthly scrub. OS lives on a separate ext4 SSD. |
| `nfs.nix`          | NFSv4 export of `/tank/share` to the LAN + VPN subnets only (edit `lanSubnet`). |

The OS-disk layout is in `hosts/home-server/disk.nix`; the ZFS `hostId` is in
`hosts/home-server/hardware.nix`.
