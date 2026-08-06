# Architecture decisions

The key choices behind this config and why, one line each. The reasoning that
matters lives here; the rest is in the Nix code and `git log`.

## Structure
- **Plain flake, no flake-parts** — four hosts don't justify the abstraction; a
  small `lib/mkHost.nix` factory keeps `flake.nix` readable.
- **home-manager as a NixOS module** — one `nixos-rebuild switch` updates system
  + home atomically; a single generation rolls both back together.
- **`core` vs `base` split** — `core` is the machine-agnostic baseline (boot,
  nix, networking, users, secrets, updates, hardening); `base` adds the
  workstation extras (GUI apps, PipeWire, libvirt, fonts, home modules). The
  headless `home-server` imports `core` directly and skips the desktop weight.

## Platform
- **nixpkgs: `nixos-unstable`** — Hyprland and chaotic-nyx track unstable; a
  stable branch would mean constant backporting.
- **Username `maudi`** on every host; **`stateVersion = 25.05`**.
- **Hyprland** from the upstream Hyprland flake input.
- **CachyOS kernel + `scx` scheduler** on the **desktop only**, via the
  chaotic-cx/nyx flake input and its binary cache. Laptops (Intel) never pull it.

## Storage & secrets
- **disko-declared disks.** All workstations (laptops + desktop): **LUKS2 + ext4
  + zram**, passphrase at boot — the desktop's earlier no-LUKS exemption
  (unattended boot at home) was reversed in favour of encryption at rest.
  home-server: SSD root + ZFS data pool (unencrypted; must boot unattended).
- **sops-nix secrets.** Each host decrypts with its SSH host ed25519 key
  converted to age; a personal master age key (private half in the password
  manager) is a recipient on every secret for recovery/re-keying. Scheme and
  enrollment steps live in `modules/nixos/core/README.md`.
- **WireGuard server key on sops.** The home-server's `wg0` private key is a
  `sops.secrets` entry (`secrets/home-server/wireguard.yaml`), not a hand-created
  `/etc/wireguard/wg0.key`, so it is versioned and decrypts at activation.
- **home-server installed with nixos-anywhere.** The one headless host is brought
  up remotely; its SSH host key is pre-generated and pushed via `--extra-files`
  so its age identity is enrolled before first boot and sops decrypts on boot.
  The workstations keep the local `scripts/install.sh` (ISO) flow.

## Theming
- **stylix** derives the palette from `modules/nixos/desktop/wallpaper.png` at
  build time and themes the apps (kitty/GTK/Qt); hyprland keeps its custom
  gradient borders read from `config.lib.stylix.colors`.
- **Noctalia is the desktop shell** (replaces the waybar/rofi/swaync/swaylock/
  swayidle/swaybg/wlogout stack) — one native Wayland shell for bar, launcher,
  notifications, control center, OSD, lock, wallpaper and session menu.
- **Split theming, shared wallpaper** — Noctalia colours its own UI from the
  wallpaper (`theme.source = "wallpaper"`); stylix themes the apps from the same
  image. `theme-sync-wallpaper` copies Noctalia's chosen wallpaper to the stylix
  source and rebuilds, so both track one picture without runtime file collisions.

## Editor
- **Neovim is declarative via nixvim** (revises the earlier "keep lazy.nvim as-is"
  choice): no Lua files or runtime plugin clones, plugins from nixpkgs, look/feel
  unchanged (ember colorscheme, same keymaps). Config in `modules/home/neovim/`.

## Updates
- **Daily `system.autoUpgrade`** (`allowReboot = false`) from the committed
  `flake.lock`; CI bumps the lock (`update-lock.yml`).
- **All hosts track the CI-gated `release` branch**, which only advances to a
  `main` commit whose full CI is green. Promotion model:
  `modules/nixos/core/README.md`.
- **Update staleness is surfaced by the Nix Monitor bar widget** (community
  plugin), which compares the system's nixpkgs revision against the tracked
  branch. It replaced a hand-written widget that watched the repo's own release
  branch — one less thing to maintain for roughly the same signal.
- **Noctalia plugins come from one Nix store path**, never from Noctalia's own
  git sources: community plugins are pinned as the `noctalia-community-plugins`
  flake input and copied into a single `kind = "path"` source (auto-update off),
  so plugin code changes only via a reviewed lock bump.
- **First-login password**: hosts ship a hashed throwaway password, force-expired
  once at first activation so `maudi` must set a real one.

## Per-host opt-ins
- **gaming** (CachyOS, Steam, AMD GPU) — desktop only.
- **Performance mode is gamemode, not power-profiles-daemon** (desktop) — the Zen 2
  CPU has no CPPC/EPP, so `amd_pstate` fails to init and PPD runs with a placeholder
  driver: its balanced/power-saver profiles are no-ops and it can never show
  `performance`. `programs.gamemode` flips the governor per game session instead.
- **waydroid** (Android container) — private-laptop + desktop; never work-laptop.
- **server** (WireGuard server, SSH-over-VPN, ZFS, NFS) — home-server only.
- **Reverse proxy = Nginx Proxy Manager container** (UI-driven LE certs), not
  native `services.nginx`/`security.acme` — home-server only. Admin UI is
  published on the VPN address (`10.100.0.1:81`), not merely firewalled, because
  podman's port-publish DNAT bypasses the input-chain firewall. Containers run
  rootful-but-hardened (`no-new-privileges`); no service container ever mounts
  the podman/docker management socket.
- **Self-hosted forge = native `services.forgejo`** (SQLite, state on the SSD,
  nightly `forgejo dump` to the ZFS pool) behind the NPM proxy — the first native
  web service on the box; everything else there is a container. GitHub is demoted
  to a per-repo push-mirror target, not the source of truth. Forgejo's built-in
  git-SSH server on 2222 (LAN/VPN only) rather than host sshd, so keys live in
  Forgejo's database and `:22` stays admin-only. Neither port is globally open:
  both are admitted by source-restricted `extraInputRules`, as with NFS.
- **Actions run on a native `gitea-actions-runner`** (`forgejo-runner` package)
  driving the *rootful* podman socket via `DOCKER_HOST` — a host service, not a
  container with the socket mounted, so the escape guard still holds. That access
  is root-equivalent, so it is only acceptable on a single-user instance
  (`DISABLE_REGISTRATION`); `enable`-gated because its registration token can
  only be minted after the forge is running.
- **net / home-server client** (`services.homeServerClient`) — desktop +
  private-laptop. WireGuard client of the server (split-tunnel, so `ssh
  home-server` works — server SSH is wg0-only) + `x-systemd.automount` NFS share.
  Desktop mounts over the LAN (no crypto on big files), the laptop over the VPN.
  `enable`-gated so an un-enrolled host (and keyless CI) still builds.
- **work-laptop hardening** — longer auto-suspend (30 min), WireGuard client +
  sops; no gaming, no waydroid (policy-bound machine).
- **Public DNS = proxied wildcard AAAA (`*.mauderer.work`), IPv6-only, kept
  current by `services.cloudflare-dyndns`** — home-server only. The ISP prefix is
  dynamic, so the record is refreshed every 5 min using a sops-held Cloudflare
  token scoped to the zone. Requires IPv6 privacy
  extensions off (`networking.tempAddresses = "disabled"`), otherwise the
  discovered address is a rotating temporary one.
- **Shared database = native `services.postgresql`, socket-only, pinned major** —
  home-server. One cluster for services added later rather than another embedded
  SQLite per service; it ships empty, and a service claims a database from its own
  module via `ensureDatabases`/`ensureUsers`. `listen_addresses` is forced to `""`
  because `enableTCPIP = false` still binds loopback, so there is no TCP listener
  and therefore no firewall rule — the WAN surface is untouched. Peer auth over
  the socket means no database password exists to keep in sops. The package is
  pinned (`postgresql_18`) rather than inherited from the `stateVersion` ladder:
  an unpinned major that moves silently initialises a *new empty cluster* instead
  of failing. Cluster on the SSD with a nightly `pg_dumpall` to the pool, the same
  split as Forgejo. Forgejo and Paperless were deliberately **not** migrated —
  they work, and a migration buys nothing until something needs concurrency.
- **Document archive = native `services.paperless`, SQLite, VPN-only** —
  home-server. `:28981` is admitted on `wg0` only and deliberately *not* given an
  NPM proxy host, so unlike Forgejo it has no WAN surface: a paper archive is the
  one service here with no reason to be public. All of it — database, search
  index, media and the nightly `document_exporter` — lives on the ZFS pool, not
  split SSD/pool like Forgejo, because the documents are irreplaceable and the
  workload isn't latency-bound. The consumption folder sits inside the NFS export
  (`/hdd_pool_1/share/paperless-inbox`) so any client that mounts the share has a
  drop folder. `/hdd_pool_1/services` is therefore `root:root 0755`: six
  service oneshots create siblings there with no ordering between them, so a
  group-owned `0750` parent can only work for one of them.
- **Push notifications = native `services.ntfy-sh`, public through NPM, closed by
  default** — home-server. The exposure call is the opposite of Paperless's and
  for the same reason: a notification that only arrives while the phone is on the
  VPN is not a push notification, so `:2586` gets an NPM proxy host
  (`ntfy.mauderer.work`) and is admitted from the podman bridge and `wg0` only —
  no new WAN ports. Being public is exactly why it ships shut:
  `auth-default-access: deny-all`, no self-signup, `behind-proxy` on so rate
  limiting sees real clients, and attachments disabled so it is not a public
  upload target. Accounts and tokens are created with the `ntfy` CLI rather than
  declared in Nix: `auth-users`/`auth-tokens` would put bcrypt hashes and live
  tokens in the world-readable store, and the only alternative — an
  `environmentFile` sops secret — buys little for three accounts. State (auth db
  + a 12 h message cache) stays on the SSD with no ZFS-pool path and no backup:
  it is four commands to recreate, and anything worth keeping belongs in the
  service that sent the notification.
- **Observability = native Prometheus + Loki + Grafana, Grafana VPN-only** —
  home-server. Three modules (`metrics.nix`, `logs.nix`, `grafana.nix`), native
  services rather than the usual container, and no new WAN ports. Grafana is on
  `:3030` (3000-3010 is taken, as for Paperless), admitted on `wg0` only and
  deliberately given no NPM proxy host — a dashboard of the whole box is the last
  thing that should answer on the WAN. Prometheus and the node/smartctl exporters
  bind `127.0.0.1` and are never firewalled open at all: Prometheus scrapes the
  exporters over loopback and Grafana queries Prometheus, so the whole metrics
  path stays on the box. Loki's `:3100` is the one exception: it is push *and* query with no
  authentication, so it is admitted from the podman bridge, LAN and VPN by a
  source-restricted rule (as with NFS and Forgejo) precisely so deployments can
  ship to it — that restriction *is* the access control.
- **Split storage for observability, for two different reasons** — Loki's chunks
  and Grafana's SQLite live on the ZFS pool (bulky, and hand-built dashboards are
  the one part that cannot be regenerated); Prometheus' TSDB stays on the SSD
  because `services.prometheus.stateDir` is a name relative to `/var/lib`, not a
  free path, and samples are derived data anyway. Loki retains 90 days;
  Prometheus retains up to 90 days and at most 20 GiB of TSDB blocks, trimming on
  whichever trips first. The size limit bounds Prometheus' own blocks rather than
  guaranteeing free space on the root disk — `node_filesystem_avail_bytes`, which
  the stack already scrapes, is what watches the SSD itself.
- **Journal shipping is Grafana Alloy, not Promtail** — Promtail reached upstream
  end of life in early 2026; Alloy's config is more verbose but is the component
  that will still exist. Relabel rules promote only low-cardinality journal fields
  (unit, host, priority, syslog identifier) to Loki labels, since one stream per
  label combination is how a Loki instance is usually ruined.
- **Alloy stays on `DynamicUser`; sources it cannot read are brought to it** —
  every service on this box is a native systemd unit, so the journal source
  already covers all of them and a new service needs no change to `logs.nix`. The
  two things outside the journal are handled without de-hardening the agent: NPM's
  nginx log *files* get a dedicated `npm-logs` group (setgid on the directory, so
  a new proxy host's log inherits it) rather than Alloy getting a static uid, and
  auditd's events are fanned into syslog with `auditd.plugins.syslog` rather than
  Alloy being given a path it can never be granted — `/var/log/audit` is 0700 and
  recreated on rotation, which no ACL can follow for a uid that changes. Only
  `status`, `method` and `vhost` become labels on access lines; the client IP
  stays in the line, because one stream per visitor is the same trap as above.
- **Dashboards are hand-written and provisioned from Nix, not vendored** — four
  small boards (host, services, logs, HTTP) naming this box's actual units,
  mountpoints and proxy hosts, instead of importing a grafana.com board where half
  the panels are for hardware that is not here. They are read-only in the UI by
  construction (the JSON is a store path), so the edit loop is "change the file,
  rebuild"; dashboards built in the browser stay in the SQLite database and are
  untouched, because provisioning adds and never cleans up.
- **Alerting is Grafana's own, delivered to the ntfy already on the box** — not
  Alertmanager, which would be a fourth daemon plus a format bridge and could not
  evaluate the one Loki-based rule. Rules, contact point, notification policy and
  the message template are all provisioned from Nix, so the alerting config is
  reviewable in the repo rather than clicked into the database. The webhook posts
  ntfy's JSON publishing format via a custom payload template — Grafana's stock
  envelope would arrive on the phone as unreadable JSON — with every string built
  through `printf "%q"` so a quote in an alert summary cannot silently produce a
  400. The publish token lives in sops as an **env-file line** and is interpolated
  by Grafana's provisioner, which is also the moment `grafana-secret-key` stopped
  being safely rotatable in practice: the contact point's credential is now stored
  encrypted under it.
- **Uptime is probed from outside, not health-checked from inside** — a blackbox
  probe of `git.mauderer.work` and `ntfy.mauderer.work` covers DNS, the dynamic
  AAAA record, the Cloudflare edge, NPM and the backend in one `probe_success`,
  which a loopback check cannot: the box's most likely public failure is a stale
  DNS record or an expired certificate while every local unit is happily active.
  Note the probed certificate is Cloudflare's edge one while the record is
  proxied. The Postgres exporter is the mirror image — the one exporter with a
  database behind it, and it still carries no credential, because it runs as the
  `postgres` user over the Unix socket and peer auth does the rest.
