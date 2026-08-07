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
| `postgresql.nix`   | **Shared database server** (`services.postgresql`, pinned `postgresql_18`) for services added later — ships as an empty cluster, no databases or roles. Reachable over the Unix socket **only**: `listen_addresses` is forced to `""`, because `enableTCPIP = false` alone still binds `127.0.0.1:5432`. No firewall rule exists or is needed. Local auth is upstream's **peer** default, so a role is reachable only by the system user of the same name and no password lands in sops. Cluster on the SSD (`/var/lib/postgresql/18`); nightly `pg_dumpall` to `/hdd_pool_1/services/postgresql/dump` (zstd, current + one `.prev` only). |
| `metrics.nix`      | **Prometheus** (`:9090`) plus the **node** (`:9100`) and **smartctl** (`:9633`) exporters — CPU/memory/disk/network/ZFS-ARC metrics, systemd unit state, and SMART drive health for the pool disks. All three bind `127.0.0.1` and are never firewalled open: Prometheus scrapes the two exporters over loopback, and Grafana queries Prometheus from the same host, so nothing here is read from off the box. TSDB on the SSD (`/var/lib/prometheus2`, `services.prometheus.stateDir` is `/var/lib`-relative), bounded at 90 days / 20 GiB. |
| `logs.nix`         | **Loki** log store (`:3100`) + **Grafana Alloy** shipping the systemd journal into it. `:3100` is push *and* query with no authentication, so it is admitted by a source-restricted rule from the podman bridge, LAN and VPN only — that restriction *is* the access control. Chunks, index and compactor on the pool under `/hdd_pool_1/services/loki`, 90-day retention. |
| `grafana.nix`      | **Grafana** (`:3030` — off the reserved 3000-3010 range), admitted **only on `wg0`** and deliberately *not* proxied through NPM, so it has no WAN surface (`http://10.100.0.1:3030`). Prometheus + Loki datasources provisioned from Nix, as are the three baseline dashboards in `dashboards/` (`host.json`, `logs.json`, `stack.json` → a read-only **NixOS** folder); the General folder stays UI-owned for scratch dashboards and pasted-in community JSON. Provisioned dashboards can't be saved from the UI — export the JSON, replace the file, rebuild. SQLite state on the pool at `/hdd_pool_1/services/grafana`. Two sops secrets in `secrets/home-server/grafana.yaml` (**bare values**, owned by `grafana`, read via Grafana's `$__file{}` provider): `grafana-admin-password`, and `grafana-secret-key` — the key encrypting secrets *inside* Grafana's database, which nixpkgs now requires and which must not be rotated once anything is stored. |
| `zfs.nix`          | Imports the pre-existing **ZFS data pool** (`extraPools`, `hdd_pool_1`) on the RAID LUN; monthly scrub. OS lives on a separate ext4 SSD. |
| `nfs.nix`          | NFSv4 export of `/hdd_pool_1/share` to the LAN + VPN subnets only (edit `lanSubnet`). |

The OS-disk layout is in `hosts/home-server/disk.nix`; the ZFS `hostId` is in
`hosts/home-server/hardware.nix`.

`/hdd_pool_1/services` is shared by `reverse-proxy.nix`, `forgejo.nix`,
`paperless.nix`, `postgresql.nix`, `logs.nix` and `grafana.nix`. Their six
directory-creating oneshots have no ordering between them, so they all leave that
parent as `root:root 0755` — traversable, so each unprivileged service reaches
its own subtree, which stays `0750` (`0700` for the Postgres dump, which holds
every database and role). Changing that mode in one module without the others
locks a service out of its own data.

The same six oneshots also `chmod 0755` the pool **root** `/hdd_pool_1`, because
nothing else in the repo owns its mode: `zfs.nix` imports the pool untouched, so
the mountpoint keeps whatever the box's former Proxmox install set — which was
`0750 maudi:polkituser`, not traversable by any service user. A service running
unprivileged with a `WorkingDirectory` on the pool then fails at systemd's
`CHDIR` step before it ever executes (this is what broke `grafana.service`).
Ownership is deliberately left alone — `maudi` owning the mountpoint may matter
for local access to `/hdd_pool_1/share` — and only the `o+x` bit is needed.

Every one of those oneshots exists for the same reason: `systemd.tmpfiles` runs
before `zfs-mount.service`, so a module that declares a directory on the pool the
normal way gets it created under the *unmounted* mountpoint and then hidden. Each
unit is `requiredBy`/`before` its own consumers and `after zfs-mount.service`,
which also orders the consumers after the mount for free.

To give a new service a database, declare it from that service's own module:

```nix
services.postgresql.ensureDatabases = [ "myservice" ];
services.postgresql.ensureUsers = [
  { name = "myservice"; ensureDBOwnership = true; }
];
```

Peer auth then maps the unit's system user onto the role of the same name — no
password, no host, no port. A *containerised* consumer cannot reach a Unix
socket: bind-mount `/run/postgresql` into it rather than re-enabling TCP.
