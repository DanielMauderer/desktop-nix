# Installing `home-server`

Headless services host, installed **remotely with nixos-anywhere** (no ISO
juggling on a box with no display). disko owns **only the OS SSD** (ext4, no
LUKS, unattended boot); the pre-existing **ZFS data pool** on the RAID LUN is
imported at runtime and is never touched by the install.

Because the server holds real secrets (its WireGuard key), its age identity must
exist **before** first boot. We do that by pre-generating the SSH host key and
pushing it in during the install (`--extra-files`), so sops decrypts on first
boot — no after-the-fact key enrollment.

## 0. Already prepared (committed to the repo)

The secrets-first work is done and in git:

- Admin SSH key authorized in `default.nix` (`maudi@desktop`).
- Server age key enrolled in `.sops.yaml`; WireGuard server key encrypted in
  `secrets/home-server/wireguard.yaml`.
- Client keys in `secrets/{desktop,private-laptop}/wireguard.yaml`; their public
  keys wired into `peers` (`modules/nixos/server/wireguard.nix`) and the server's
  public/host keys into the client module (`modules/nixos/net/home-server-client.nix`).
- The matching **plaintext** SSH host key + WireGuard keys are in the gitignored
  `secrets-seed/` on the desktop (used for `--extra-files` below). Keep it until
  the install succeeds.
- Service credentials that must exist at eval time are committed encrypted:
  `secrets/home-server/{cloudflare,paperless,grafana}.yaml`. The Grafana one
  ships with a random password nobody has seen — replace it in step 8.

## 1. Check before you install

- **OS SSD device** in `hosts/home-server/disk.nix` (`lsblk` on the target —
  usually `/dev/nvme0n1`). **Must NOT be the RAID LUN that holds the ZFS pool.**
- **ZFS `hostId`** in `hardware.nix` is unique; ZFS pool name (`zfs.extraPools`,
  `hdd_pool_1`) and the LAN subnet in `modules/nixos/server/nfs.nix`.
- **`nfsHost`/LAN IP** for the desktop client in `hosts/desktop/default.nix`.
- **sops master age key** is in the password manager.
- **DNS:** `vpn.mauderer.work` must be a **DNS-only (grey-cloud)** Cloudflare
  record → the WAN IP. Cloudflare's proxy does not carry WireGuard's UDP/51820.

## 2. Boot the target into an installer

Get the box onto the network in an environment nixos-anywhere can SSH into as
root — the NixOS minimal ISO (set a root password + start `sshd`) or a kexec
image. Note its IP (`<ip>`). Uncomment the hardware import in
`hosts/home-server/default.nix`:

```nix
./hardware/hardware-configuration.nix
```

## 3. Run nixos-anywhere (from the desktop, in the repo)

```sh
nix run github:nix-community/nixos-anywhere -- \
  --flake .#home-server \
  --generate-hardware-config nixos-generate-config ./hosts/home-server/hardware/hardware-configuration.nix \
  --extra-files ./secrets-seed \
  root@<ip>
```

- `--generate-hardware-config` probes the target and writes the real
  `hardware-configuration.nix` into the host dir (stage it — `git add -N
  hosts/home-server/hardware/` — if the flake build says it's untracked).
- disko (`hosts/home-server/disk.nix`) partitions the OS SSD; the ZFS LUN is
  untouched.
- `--extra-files ./secrets-seed` lands the pre-generated
  `/etc/ssh/ssh_host_ed25519_key`; the activation script in
  `modules/nixos/core/secrets.nix` keeps it (only generates one when absent), so
  the host's age identity matches `.sops.yaml`.

The box reboots into the installed system. On first boot sops decrypts the
WireGuard key with the seeded identity.

## 4. Post-install

```sh
git clone https://github.com/DanielMauderer/desktop-nix ~/desktop-nix
sudo passwd maudi           # set a real password (config ships none)
```

Enable the clients **last**, once the server is reachable: uncomment
`services.homeServerClient.enable = true;` in `hosts/desktop/default.nix` and
`hosts/private-laptop/default.nix`, then `update` on each.

## 5. Forgejo (the forge + its Actions runner)

Forgejo comes up with the rest of the system; the runner is opt-in because its
registration token can only be minted once the forge is running.

1. **First admin user.** Over the VPN, browse `http://10.100.0.1:4000` and create
   the first account — it becomes the instance admin. Self-registration is off,
   so every later account is admin-created. (Plain HTTP over WireGuard, same as
   the NPM admin UI; `:4000` is not reachable from the WAN or the LAN.) From a
   console instead of the VPN, the equivalent is:
   ```sh
   sudo -u forgejo forgejo admin user create --admin \
     --username maudi --email you@example.com --random-password \
     --config /var/lib/forgejo/custom/conf/app.ini
   ```
2. **Publish it.** In the NPM admin UI (`http://10.100.0.1:81`) add a proxy host:
   domain `git.mauderer.work`, forward to `http://10.88.0.1:4000` (the podman
   bridge gateway — i.e. this host, as seen from the NPM container), websockets
   on, then request a Let's Encrypt cert. No *new* DNS record is needed — the
   wildcard AAAA from `cloudflare-ddns.nix` already covers the name — but see
   the HTTP-01 note in §9: the wildcard has to be grey-clouded while the cert is
   issued, then switched back to proxied. In the host's
   *Advanced* tab set `client_max_body_size 0;` so large pushes aren't truncated.
3. **Runner token.** In Forgejo: Site Administration → Actions → Runners →
   *Create new runner* → copy the registration token. Then, in the repo:
   ```sh
   nix develop
   sops secrets/home-server/forgejo.yaml
   ```
   with the content — note the `TOKEN=` prefix, this is an *environment* file,
   unlike the bare Cloudflare token:
   ```yaml
   forgejo-runner-token: TOKEN=<registration token>
   ```
   Uncomment `services.forgejoRunner.enable = true;` in
   `hosts/home-server/default.nix`, commit, and `switch`. The runner should show
   as idle in the admin panel.
4. **GitHub backup mirror**, per repository: Settings → Mirror Settings → *Push
   Mirror*, target
   `https://<github-user>:<PAT>@github.com/<user>/<repo>.git`, interval `8h`.
   The PAT needs only `repo` scope and lives in Forgejo's database — never in
   this repo. Use *Synchronize now* once to confirm.

Two limits worth knowing:

- Git over **HTTPS** goes through Cloudflare, which caps request bodies at 100 MB
  on the free plan. A very large push can fail there.
- Git over **SSH** (port 2222) is LAN/VPN-only by design — Cloudflare's proxy
  can't carry an arbitrary SSH port anyway, and opening one would break the
  "WAN surface is exactly 80/443/51820" assertion. It has no size limit, so it's
  the escape hatch for big pushes.

## 6. Paperless (the document archive)

Paperless comes up with the rest of the system — there is no bootstrap step and
nothing to publish. Unlike Forgejo it is **VPN-only by design**: do *not* add a
proxy host for it in NPM, that is what would give it a WAN surface.

1. **Log in.** With the VPN up, browse `http://10.100.0.1:28981`. The user is
   `admin`; the password is the sops secret created with the repo:
   ```sh
   nix develop
   sops -d secrets/home-server/paperless.yaml   # read it
   sops secrets/home-server/paperless.yaml      # change it
   ```
   The password is applied on every start, so a `switch` after editing is enough
   to rotate it — the key is `paperless-admin-password`, a **bare** password (no
   `KEY=` prefix, unlike the Forgejo runner token).
2. **Drop documents in.** The consumption folder is `/hdd_pool_1/share/
   paperless-inbox`, inside the NFS export — so on a client that mounts the
   share it is `/mnt/home-server/paperless-inbox`. Anything copied there is
   OCR'd and filed within a minute, then removed from the inbox. Scanners that
   can write to an NFS/SMB share can target it directly.
3. **Filed documents** land under `/hdd_pool_1/services/paperless/media` as
   `{created_year}/{correspondent}/{title}`, so the archive stays navigable
   without the database. OCR runs in German and English.

Worth knowing:

- **Backups.** `systemctl list-timers paperless-exporter` shows the nightly
  01:30 export into `/hdd_pool_1/services/paperless/export` — documents plus
  metadata as files and JSON, restorable with `paperless-manage
  document_importer`, and independent of the SQLite schema. It stops the
  paperless services while it runs and restarts them after.
- **The inbox is world-writable** (mode 0777, no sticky bit) so NFS clients can
  write to it and paperless can delete what it has consumed. It is a transient
  drop folder — nothing should be stored there.
- `paperless-manage` is on `PATH` on the server for admin tasks
  (`paperless-manage createsuperuser`, `document_exporter`, …).

## 7. ntfy (push notifications)

ntfy comes up with the rest of the system, but it starts **closed**: with
`auth-default-access: deny-all` and no accounts yet, every request except the
health endpoint is answered with 403. That is deliberate — unlike Paperless this
one *is* published, so it has to be shut the moment it becomes reachable.

1. **Publish it.** In the NPM admin UI (`http://10.100.0.1:81`) add a proxy host:
   domain `ntfy.mauderer.work`, forward to `http://10.88.0.1:2586` (the podman
   bridge gateway — this host as the NPM container sees it), **websockets on**
   (the phone apps hold a WebSocket; without this they silently never connect),
   then request a Let's Encrypt cert. As with Forgejo, no *new* DNS record is
   needed — the wildcard AAAA from `cloudflare-ddns.nix` already covers the name
   — but the cert still has to be issued against a **grey-clouded** wildcard
   (§9), and the wildcard is shared, so that toggle briefly takes every
   `*.mauderer.work` host off the Cloudflare proxy. Do it once, issue both
   certs, switch back.
2. **Create the accounts**, on the server, **as root**. `ntfy` reads
   `/etc/ntfy/server.yml` and edits the auth database directly, and the database
   lives under `/var/lib/private` because the unit uses `DynamicUser` — so
   `sudo -u ntfy-sh …` cannot reach it. `NTFY_PASSWORD` is what makes these
   non-interactive (there is no `--password` flag) and it has to be passed
   through `env`, since `sudo` clears the environment:
   ```sh
   # you: full access, used to log in from the phone
   sudo env NTFY_PASSWORD='<phone password>' ntfy user add --role=admin maudi

   # your services: may publish, may not read anything back
   sudo env NTFY_PASSWORD="$(head -c 24 /dev/urandom | base64)" ntfy user add svc
   sudo ntfy access svc '*' write-only
   sudo ntfy token add svc          # prints tk_… — this is what services use
   ```
   `svc`'s password is a throwaway that is never read back — services
   authenticate with the token, not with it. `sudo ntfy access` with no arguments
   prints the whole ACL to check the result. Changes take effect immediately;
   no restart is needed.
3. **Send a notification** from any service, host or script:
   ```sh
   curl -H "Authorization: Bearer tk_…" \
        -H "Title: ZFS scrub" -H "Priority: high" -H "Tags: warning" \
        -d "hdd_pool_1 finished with errors" \
        https://ntfy.mauderer.work/alerts
   ```
   The topic (`alerts` here) is just a path segment — invent one per source. The
   `svc` ACL above covers all of them; narrow it to `ntfy access svc 'alerts*'
   write-only` if you'd rather whitelist.
4. **The phone.** Install the ntfy app, add the server
   `https://ntfy.mauderer.work` under *Settings → Manage users* with the `maudi`
   credentials, then subscribe to the topics. On **iOS** only, uncomment
   `upstream-base-url` in `modules/nixos/server/ntfy.nix` and `switch`: Apple
   requires APNs, which a self-hosted instance cannot speak, so the app polls
   ntfy.sh and this box forwards a *hash* of the topic (never the message) there.
   Android's app keeps its own WebSocket and needs nothing.

Worth knowing:

- **Nothing here is backed up**, on purpose. The message cache is transient by
  design (12 h) and the auth database is these four commands — if the SSD dies,
  recreate the accounts and re-issue the token. Everything worth keeping belongs
  in the service that sent the notification.
- **Attachments are disabled** — `ntfy.nix` blanks `attachment-cache-dir`, which
  it has to do explicitly because the NixOS module defaults it to a real path. A
  publish token that can also fill a disk is a different risk profile; use the
  `Click`/`Attach` headers pointing at an existing URL instead.
- Accounts *can* be declared in Nix instead (`auth-users`/`auth-access`/
  `auth-tokens` via `services.ntfy-sh.environmentFile`), but each entry is a
  bcrypt hash or a live token, so it would need a sops secret — see the comment
  in `ntfy.nix` before going that way.
## 8. Observability (metrics, logs, dashboards)

Prometheus, Loki, Grafana Alloy and Grafana come up with the rest of the system.
Like Paperless, Grafana is **VPN-only by design** — do *not* add a proxy host for
it in NPM.

1. **Set the Grafana admin password.** The repo ships a random one that nobody
   has seen; replace it with your own before the first login:
   ```sh
   nix develop
   sops secrets/home-server/grafana.yaml   # key: grafana-admin-password
   ```
   It is a **bare** password (no `KEY=` prefix, like the Paperless one). Commit,
   then `switch` — Grafana re-reads the file on every start, so a rebuild is all
   a rotation needs.

   The same file holds `grafana-secret-key`, which encrypts secrets *inside*
   Grafana's database. **Leave it alone.** It also ships random, which is what
   you want, and unlike the admin password it cannot be rotated: the database is
   encrypted under it and there is no official re-key path, so changing it
   orphans anything already stored. Harmless before first use, not after.
2. **Log in.** With the VPN up, browse `http://10.100.0.1:3030` as `admin`. The
   port is 3030, not Grafana's default 3000, because 3000-3010 is already spoken
   for on this box.
3. **Datasources are already there.** `Prometheus` and `Loki` are provisioned
   from Nix (`modules/nixos/server/grafana.nix`) and are read-only in the UI —
   edit them in that file, not in the browser.
4. **Import dashboards.** Nothing is provisioned: use *Dashboards → New →
   Import* and paste a grafana.com dashboard ID. `1860` (Node Exporter Full) is
   the one to start with; `13639` gives a Loki log view. Imported dashboards live
   in the SQLite database on the pool, so they survive an SSD rebuild.

Worth knowing:

- **What is scraped:** the host's node exporter (CPU, memory, disks,
  filesystems, network, hwmon temperatures, ZFS ARC, systemd unit state), the
  smartctl exporter (per-drive SMART health for the pool disks and the NVMe
  root), and Prometheus, Loki, Alloy and Grafana themselves.
- **Retention** is 90 days on both sides. Prometheus additionally caps its TSDB
  blocks at 20 GiB and trims on whichever limit trips first. That cap bounds
  Prometheus, not the SSD as a whole — watch `node_filesystem_avail_bytes` for
  the disk itself, which this stack scrapes for you.
- **Pushing from your own deployments.** Loki's `:3100` is reachable from the
  podman bridge (`10.88.0.0/16`), the LAN and the VPN, so a container on this box
  can push to `http://10.88.0.1:3100/loki/api/v1/push`. There is **no
  authentication** on that port — the source restriction is the access control,
  so never add it to `allowedTCPPorts`. To have Prometheus scrape a deployment,
  add a job to `scrapeConfigs` in `modules/nixos/server/metrics.nix`.
- **No alerting yet.** Alertmanager is deliberately not configured — it needs a
  notification route (SMTP or a webhook, plus a sops-held credential) that hasn't
  been chosen.

## 9. Verify

- On the server: `journalctl -u sops-nix` shows the WireGuard key decrypted;
  `wg show` lists `wg0` with the two client peers.
- SSH reachable **only over the VPN** (port 22 closed on the WAN — there is no
  LAN fallback); from an enabled client `ssh home-server` has no TOFU prompt
  (host key pinned).
- `zpool status` / `zfs list` show the data pool; `showmount -e <server>` lists
  the export; `nft list ruleset` shows only UDP 51820 + TCP 80/443 open on the
  WAN (SSH 22, the NPM admin UI 81, Paperless 28981, Grafana 3030, Loki 3100 and
  NFS 2049 stay off the WAN).
- **Reverse proxy:** `podman ps` lists the `npm` container. Over the VPN, browse
  `http://10.100.0.1:81` (default login `admin@example.com` / `changeme` — change
  it on first use) to add proxy hosts and request Let's Encrypt certs. HTTP-01
  validation has to reach NPM directly, so set the `*.mauderer.work` wildcard to
  **DNS-only (grey-cloud)** first, issue the certs, then switch it back to
  proxied. Behind the orange cloud the challenge is answered by Cloudflare's
  edge, which cannot serve a token NPM has not been given. The wildcard covers
  every published host, so grey-clouding it takes them all off the proxy for the
  duration — issue new certs in one pass rather than one host at a time.
- **Forgejo:** `systemctl status forgejo` and `curl -fsS
  http://10.100.0.1:4000/api/healthz`; `systemctl list-timers forgejo-dump` shows
  the nightly dump, which lands in `/hdd_pool_1/services/forgejo/dump`. Once the
  runner is enabled, `systemctl status gitea-runner-forgejo` plus a trivial
  `.forgejo/workflows/hello.yml` in a scratch repo proves the podman job path.
- **Paperless:** `systemctl status paperless-web` and `curl -fsS -o /dev/null -w
  '%{http_code}\n' http://10.100.0.1:28981/accounts/login/` (expect `200`); the
  port must answer over the VPN and **not** from the LAN or the WAN. Copy a PDF
  into `/hdd_pool_1/share/paperless-inbox` and watch `journalctl -u
  paperless-consumer -f` ingest it.
- **ntfy:** `systemctl status ntfy-sh` and, over the VPN, `curl -fsS
  http://10.100.0.1:2586/v1/health` (expect `{"healthy":true}`). `nft list
  ruleset | grep 2586` must show the source-restricted rule, not a globally open
  port — 2586 answers only from the podman bridge and the VPN, never the WAN
  directly. Then prove the door is shut and the key works:
  ```sh
  curl -fsS -d hi https://ntfy.mauderer.work/alerts                   # must FAIL (403)
  curl -fsS -H "Authorization: Bearer tk_…" -d hi https://ntfy.mauderer.work/alerts
  ```
  The second one landing on the phone is the only check that covers the proxy
  host, the certificate and the app together.
- **Observability:** `curl -fsS 'http://127.0.0.1:9090/api/v1/targets?state=active'
  | jq -r '.data.activeTargets[] | "\(.labels.job) \(.health)"'` should list six
  jobs, all `up`. If `prometheus-smartctl-exporter` is failed, the drives are
  hidden behind the RAID HBA — see the `devices` note in
  `modules/nixos/server/metrics.nix`. Over the VPN, `http://10.100.0.1:3030`
  serves Grafana and
  `curl -fsS http://10.100.0.1:3100/ready` answers for Loki; neither must answer
  from the WAN. Then check logs are flowing:
  `logcli` isn't installed, so use Grafana's *Explore* on the Loki datasource
  with `{job="systemd-journal"}` — journal lines should appear within a minute
  of `systemctl status alloy` going green.
- Once verified, delete `secrets-seed/` on the desktop.
- Rollback drill: break something, `switch`, reboot, pick the prior generation.
