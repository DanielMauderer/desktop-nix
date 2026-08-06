# server

The home-server's service stack — imported only by `hosts/home-server`.
Everything here is deliberately absent from the workstation `base`.

| File               | Configures                                                   |
|--------------------|-------------------------------------------------------------|
| `ssh.nix`          | OpenSSH re-enabled (key-only, no root), admitted **only on the `wg0` VPN interface** — never the WAN. |
| `wireguard.nix`    | WireGuard **server** (`wg0`, `10.100.0.0/24`, the box is `.1`). Private key is a sops secret (`secrets/home-server/wireguard.yaml`), decrypted at activation; client public keys added to `peers`. UDP 51820 is the only WAN port. |
| `reverse-proxy.nix`| **Nginx Proxy Manager** container (LE certs + proxy hosts via its web UI). Public HTTP/HTTPS on `80`/`443`; admin UI published on the VPN address only (`10.100.0.1:81`). Data under `/hdd_pool_1/services/npm`. Certs via HTTP-01. Hardened: no socket mount, `no-new-privileges`. |
| `cloudflare-ddns.nix`| **Dynamic DNS**: publishes the box's current public IPv6 into Cloudflare's proxied AAAA record for `*.mauderer.work` every 5 min (`services.cloudflare-dyndns`, AAAA only). API token is a sops secret (`secrets/home-server/cloudflare.yaml`, key `cloudflare-api-token`, **bare token**). Also disables IPv6 privacy extensions so the published address is the stable one. |
| `containers.nix`   | Container-host groundwork for docker-compose / Ansible services. |
| `forgejo.nix`      | **Self-hosted forge** (`services.forgejo`, SQLite, LFS), served as `https://git.mauderer.work` through NPM. HTTP `:4000` admitted only from the podman bridge (the proxy) and the VPN (admin access at `http://10.100.0.1:4000`), built-in git-SSH `:2222` only from LAN/VPN — no new WAN ports. Self-registration off, Actions on, `DEFAULT_ACTIONS_URL = github`, push mirroring on (GitHub is the backup target). State on the SSD; nightly `forgejo dump` to `/hdd_pool_1/services/forgejo/dump`. |
| `forgejo-runner.nix`| **Forgejo Actions runner** (`services.forgejoRunner`, **opt-in**, default off). Jobs run as podman containers via `forgejo-runner`. Registration token is a sops secret (`secrets/home-server/forgejo.yaml`, key `forgejo-runner-token`, **`TOKEN=…` env-file format**). Runs as a host service holding the rootful podman socket — root-equivalent, hence single-user-forge only. |
| `paperless.nix`    | **Document archive** (`services.paperless`, SQLite, OCR `deu+eng`). HTTP `:28981` admitted **only on `wg0`** — deliberately *not* published through NPM, so it has no WAN surface at all (`http://10.100.0.1:28981`). All state, media and the nightly `document_exporter` run live on the ZFS pool under `/hdd_pool_1/services/paperless`; the drop folder is `/hdd_pool_1/share/paperless-inbox`, inside the NFS export. Admin password is a sops secret (`secrets/home-server/paperless.yaml`, key `paperless-admin-password`, **bare password**). |
| `ntfy.nix`         | **Push notifications** (`services.ntfy-sh`), served as `https://ntfy.mauderer.work` through NPM so notifications arrive off-LAN — the opposite exposure call from `paperless.nix`, and the reason the instance is closed: `auth-default-access: deny-all`, no self-signup, `behind-proxy` on. HTTP `:2586` admitted only from the podman bridge (the proxy) and the VPN — no new WAN ports. Attachments deliberately off — `attachment-cache-dir` is blanked, which the module has to do explicitly because upstream defaults it to a real path, so it is not a public upload target. State is the auth db + a 12 h message cache under `/var/lib/ntfy-sh` on the SSD — no ZFS pool path, hence no mount-ordering oneshot. **No sops secret**: users/tokens are created with the `ntfy` CLI (as root — `DynamicUser` puts the db under `/var/lib/private`), because the declarative `auth-users` route would put bcrypt hashes and live tokens in the world-readable Nix store. |
| `zfs.nix`          | Imports the pre-existing **ZFS data pool** (`extraPools`, `hdd_pool_1`) on the RAID LUN; monthly scrub. OS lives on a separate ext4 SSD. |
| `nfs.nix`          | NFSv4 export of `/hdd_pool_1/share` to the LAN + VPN subnets only (edit `lanSubnet`). |

The OS-disk layout is in `hosts/home-server/disk.nix`; the ZFS `hostId` is in
`hosts/home-server/hardware.nix`.

`/hdd_pool_1/services` is shared by `reverse-proxy.nix`, `forgejo.nix` and
`paperless.nix`. Their three directory-creating oneshots have no ordering between
them, so they all leave that parent as `root:root 0755` — traversable, so each
unprivileged service reaches its own subtree, which stays `0750`. Changing that
mode in one module without the others locks a service out of its own data.
