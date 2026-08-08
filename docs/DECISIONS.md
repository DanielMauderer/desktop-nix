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
  native `services.nginx`/`security.acme` — home-server only. It runs with
  **`--network=host`, publishing no ports**, which reverses the earlier
  "publish the admin port on `10.100.0.1:81`" model. That model existed because
  podman's publish DNAT bypasses the input-chain firewall — true, but it also
  only ever emitted rules in the nftables `ip` family, and this box is IPv6-only
  inbound (DS-Lite), so `:80`/`:443` refused every v6 connection: Let's Encrypt's
  HTTP-01 fetch and Cloudflare's origin alike. In the host netns nginx is an
  ordinary host listener with no DNAT, so `allowedTCPPorts` governs it and the
  wg0-only rule is what keeps `:81` off the WAN. Cost: this one container gives
  up its network namespace (mount/PID/user namespaces and the hardening below
  are untouched), and upstreams must be `127.0.0.1` in NPM's UI rather than the
  podman bridge gateway. Containers run rootful-but-hardened
  (`no-new-privileges`); no service container ever mounts the podman/docker
  management socket.
- **Certificates are issued by DNS-01, not HTTP-01** — the corollary of the
  IPv6-only inbound path. DNS-01 needs no inbound connectivity, survives the
  orange cloud (which is not optional here: with no public IPv4, the Cloudflare
  proxy is the only path for v4 visitors), and is the sole option for a
  wildcard. The Cloudflare credential is entered in NPM's UI and lives in
  container state on the pool — the `cloudflare-api-token` sops secret is
  `cloudflare-dyndns`'s, not NPM's, though the same zone scope fits both.
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
  group-owned `0750` parent can only work for one of them. The same oneshots
  `chmod 0755` the pool *root*: `zfs.nix` imports `hdd_pool_1` untouched, so its
  mountpoint mode is inherited from the box's former Proxmox install and no
  module owned it — an untraversable pool root kills any unprivileged service
  with a `WorkingDirectory` on the pool at systemd's `CHDIR` step. Mode only;
  ownership stays as-is, since `maudi` owns the mountpoint used for the share.
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
- **Baseline dashboards are provisioned from Nix; the UI keeps the scratch half**
  — `modules/nixos/server/dashboards/*.json` are handcrafted for exactly the
  metrics this box scrapes and land in a read-only `NixOS` folder, so a
  reinstalled server shows host health, logs and stack health immediately instead
  of an empty Grafana. Community dashboards (grafana.com #1860 and friends) are
  deliberately *not* vendored: they are hundreds of kilobytes, carry
  `__inputs`/`${DS_PROMETHEUS}` placeholders that appear to be an import-API
  feature rather than a file-provisioner one,
  and assume label sets this host does not have — paste those into the UI-owned
  General folder instead. The price is that provisioned dashboards cannot be saved
  from the UI: export the JSON, replace the file, rebuild.
- **Script-shaped metrics go through the node exporter's textfile collector, not
  a second exporter** — `nixos-metrics.nix` (update pipeline: pending reboot,
  autoUpgrade result, nixpkgs staleness, generations, store size) and
  `backup-metrics.nix` (freshness, size and retention of the three nightly
  backups) are hourly oneshots writing `.prom` files that the node exporter
  re-serves. No new listener, no new scrape job, and the series carry the same
  `job="node"` label as the rest of the box. Two rules the writers must follow:
  write-then-rename, because the collector parses whatever it finds and a
  partial file drops *every* textfile sample in the scrape; and never
  pre-compute an age, because `time() - metric` at query time is correct while a
  baked-in age is stale on arrival. Nothing expires a stale file, so
  `node_textfile_mtime_seconds` is the freshness guard on the dashboards.
  Backups report zeros rather than nothing for a missing directory — an absent
  sample cannot be alerted on, a zero can.
- **Alerts are delivered by the box's own ntfy, through two independent paths**
  — `alerts.nix`. No Alertmanager and no third party: the push server is already
  here, already reaches the phone off-LAN, and adding a second alerting daemon to
  route between Prometheus and it buys nothing at this scale. The two paths are
  deliberate rather than redundant. Grafana's rules can alert on anything in the
  TSDB but need Grafana, Prometheus and a working scrape loop; a systemd
  `OnFailure=` handler needs none of those, so it is the floor that still reports
  when the observability stack itself is what died. The credential is a
  **password, not a token**, because ntfy can only mint tokens itself — which
  would make sops a copy of server state; a password lets sops stay
  authoritative and `ntfy user add` consume it. It never enters the Nix store:
  the Grafana contact point is generated into `/run` by a oneshot in
  grafana.service's dependency chain, because `provision.alerting.contactPoints.settings`
  is rendered into the store. Every rule sets `noDataState = OK` — the default
  is `NoData`, which alerts on an absent series, and these rules are written so
  that absence *is* the healthy state.
- **Blackbox probes go to `127.0.0.1:443` with the real hostname as SNI, not to
  the public hostname** — `blackbox.nix`. Probing `https://ntfy.mauderer.work`
  from this box would depend on the router hairpinning, and would silently
  produce nothing if it does not. NPM publishes `:443` on all interfaces, so
  loopback reaches it; supplying the hostname through `tls_config.server_name`
  and a `Host` header makes the request indistinguishable from a real client's
  except for the network path, and exercises TLS termination plus backend
  routing — which matters because proxy hosts live in NPM's UI, not in Nix.
  Certificate verification is left on (`insecure_skip_verify` would make the
  probe pass against the expired certificate it exists to warn about). The
  honest limitation, recorded on the dashboard itself: none of this proves
  reachability from the internet, which needs a prober somewhere else. The
  exporter is loopback-only for a stronger reason than the others — anything
  that can reach `/probe` can make this box fetch a URL of its choosing.
- **A service's metrics endpoint must not inherit its service's public exposure**
  — the rule the three native endpoints follow, and they resolve it differently
  because the software allows different things. **postgres_exporter** is a
  separate loopback listener and needs no credential at all (`runAsLocalSuperUser`
  + the Unix socket = peer auth, the same argument `postgresql.nix` already makes
  for having no sops entry). **ntfy** gets `metrics-listen-http` on its own
  loopback port rather than `enable-metrics`, which would serve `/metrics` from
  the listener NPM publishes as `ntfy.mauderer.work`. **Forgejo** can do neither —
  it has one listener and NPM proxies it — so it is the single scrape target on
  this box that is not loopback-only and therefore the single one carrying a
  credential: a sops-held bearer token handed to Forgejo and to Prometheus as a
  systemd credential, never through `settings` (which is world-readable in the
  Nix store). The cost is that `services.prometheus.checkConfig` drops to
  `syntax-only`, because the full `promtool check config` stats every referenced
  file and a systemd credential does not exist at build time; the nixosTest
  recovers the lost coverage by asserting every target is healthy on a running
  instance.

- **The home-server's NetworkManager profile is an `/etc` keyfile, not
  `networking.networkmanager.ensureProfiles`.** The profile pins the IPv6
  interface ID (`ipv6.token`) that the router's exposed-host entry is keyed on,
  so it has to be in force from the link's first activation. `ensureProfiles`
  writes to `/run` from a unit ordered *after* `NetworkManager.service`, by which
  time NM has auto-generated its own profile and come up on a stable-privacy
  address; a keyfile in `/etc/NetworkManager/system-connections` is there before
  NM starts.

- **The Forgejo Actions runner is a hand-written unit, not
  `services.gitea-actions-runner`.** That module implements only the deprecated
  handshake — `forgejo-runner register --token <registration token>` — which a
  Forgejo 15 server answers with `invalid_argument: runner registration token
  not found` however freshly the token was minted, and no module in nixpkgs
  (stable or unstable) speaks the current one. In the current model the *forge*
  creates the runner and issues a UUID plus a persistent shared secret, which
  the daemon declares at startup via `--url/--uuid/--token-url`. Consequences
  that read as bugs if you don't know the switch happened: the token is a bare
  value rather than a `TOKEN=…` env-file, it is delivered by `LoadCredential`
  because the runner process (not PID 1) opens it under a DynamicUser, and there
  is no re-registration dance on token or label changes.

- **The workstations push telemetry; they are not scraped.** Their Alloy
  `remote_write`s into an ingest port on the *server's* Alloy, which forwards to
  Prometheus over loopback. Two things fall out of that shape and neither is
  incidental. Adding laptops as scrape targets would make `alerts.nix`'s
  `hs-target-down` (`up == 0` → ntfy) fire on every closed lid, so the choice is
  push or a weakened alert; `remote_write` produces no `up` series at all. And the
  extra Alloy hop exists because Prometheus' remote-write receiver shares the
  listener with its unauthenticated expression browser — writing to `:9090`
  directly would mean exposing that browser to the VPN, which `metrics.nix` argues
  against. The cost is that "is this host awake" has no `up` to read and is
  answered by the age of its newest sample.
