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

## 1. Check before you install

- **OS SSD device** in `hosts/home-server/disk.nix` (`lsblk` on the target —
  usually `/dev/nvme0n1`). **Must NOT be the RAID LUN that holds the ZFS pool.**
- **ZFS `hostId`** in `hardware.nix` is unique; ZFS pool name (`zfs.extraPools`,
  `hdd_pool_1`) and the LAN subnet in `modules/nixos/server/nfs.nix` — which
  `modules/nixos/server/dns.nix` repeats, along with the router and the server's
  own LAN address.
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
   on, then request a Let's Encrypt cert. No DNS change is needed: the proxied
   wildcard AAAA from `cloudflare-ddns.nix` already covers it. In the host's
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

## 7. Internal DNS (blocky)

Blocky comes up with the rest of the system and is immediately the *server's*
resolver. Making it the *house's* resolver takes two settings on the FRITZ!Box
and one decision about IPv6.

1. **Pin the server's address.** `modules/nixos/server/dns.nix` binds
   `192.168.178.96` by name (plus `10.100.0.1` and loopback), so a lease that
   moves leaves clients pointed at nothing. In the FRITZ!Box: *Home Network →
   Network → `home-server` → Edit →* "Always assign the same IPv4 address to
   this network device". A different address means editing `serverLanAddress`
   in `dns.nix` — and `nfsHost`/`endpoint` in `hosts/desktop/default.nix`.
2. **Hand it to the clients.** *Home Network → Network → Network Settings →
   IPv4 Settings →* "Local DNS server" = `192.168.178.96`. Clients pick it up on
   their next DHCP renewal (or a reconnect).
3. **Close the IPv6 bypass.** A dual-stack client is *also* offered the
   FRITZ!Box as a DNSv6 resolver over router advertisement, and those queries
   never reach blocky. Either point the FRITZ!Box's own upstream resolvers at
   the server (*Internet → Account Information → DNS Server*, DNSv4 =
   `192.168.178.96`), so everything it forwards is filtered as well, or turn
   DNSv6 off for the home network. Blocky binds IPv4 only, deliberately: this
   box has no *stable* IPv6 address to publish — that is the whole reason
   `cloudflare-ddns.nix` exists.

Note the trade-off in that last step. Step 2 alone leaves the FRITZ!Box's own
upstream resolvers intact, so a blocky that is down degrades to *unfiltered* DNS.
Pointing the box's upstream at the server as well closes the IPv6 gap but makes
this box a single point of failure for the whole house — including for its own
recovery, since the server's fallback resolver is then the router, which forwards
straight back. Prefer the RA/DNSv6 switch if the box offers it.

Day-to-day, from an SSH session on the server (the API is loopback-only):

```sh
blocky --apiPort 4001 query git.mauderer.work       # which resolver answered, and why
blocky --apiPort 4001 blocking disable --duration 10m   # unblock everything, briefly
blocky --apiPort 4001 lists refresh                # after editing the lists/allowlist
```

A domain that is blocked but shouldn't be goes in `blocking.allowlists.ads` in
`dns.nix` — a commit, not a click. A new local name goes in `customDNS.mapping`;
names the router already knows (`*.fritz.box`) need nothing, they are forwarded
back to it.

## 8. Verify

- On the server: `journalctl -u sops-nix` shows the WireGuard key decrypted;
  `wg show` lists `wg0` with the two client peers.
- SSH reachable **only over the VPN** (port 22 closed on the WAN — there is no
  LAN fallback); from an enabled client `ssh home-server` has no TOFU prompt
  (host key pinned).
- `zpool status` / `zfs list` show the data pool; `showmount -e <server>` lists
  the export; `nft list ruleset` shows only UDP 51820 + TCP 80/443 open on the
  WAN (SSH 22, the NPM admin UI 81, Paperless 28981, DNS 53 and NFS 2049 stay off
  the WAN).
- **Reverse proxy:** `podman ps` lists the `npm` container. Over the VPN, browse
  `http://10.100.0.1:81` (default login `admin@example.com` / `changeme` — change
  it on first use) to add proxy hosts and request Let's Encrypt certs. HTTP-01
  needs the proxied domain's A record to be **DNS-only (grey-cloud)** → WAN IP.
- **Forgejo:** `systemctl status forgejo` and `curl -fsS
  http://10.100.0.1:4000/api/healthz`; `systemctl list-timers forgejo-dump` shows
  the nightly dump, which lands in `/hdd_pool_1/services/forgejo/dump`. Once the
  runner is enabled, `systemctl status gitea-runner-forgejo` plus a trivial
  `.forgejo/workflows/hello.yml` in a scratch repo proves the podman job path.
- **Internal DNS:** `systemctl status blocky`; `ss -lunp | grep :53` lists
  `127.0.0.1`, `192.168.178.96` and `10.100.0.1` — and **not** `0.0.0.0`, which
  is what leaves `10.88.0.1:53` to podman's aardvark-dns (`podman ps` still has
  to work). From a LAN client: `dig +short @192.168.178.96 git.mauderer.work`
  answers `192.168.178.96` (split horizon), and a tracker domain such as
  `dig +short @192.168.178.96 googlesyndication.com` answers `0.0.0.0`.
  `journalctl -u blocky | grep 'group import finished'` shows both lists loaded
  (~200k + ~380k entries); they download after start, so a fresh boot blocks
  nothing for a few seconds — by design, the resolver never waits on them.
- **Paperless:** `systemctl status paperless-web` and `curl -fsS -o /dev/null -w
  '%{http_code}\n' http://10.100.0.1:28981/accounts/login/` (expect `200`); the
  port must answer over the VPN and **not** from the LAN or the WAN. Copy a PDF
  into `/hdd_pool_1/share/paperless-inbox` and watch `journalctl -u
  paperless-consumer -f` ingest it.
- Once verified, delete `secrets-seed/` on the desktop.
- Rollback drill: break something, `switch`, reboot, pick the prior generation.
