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
- **Document archive = native `services.paperless`, SQLite, VPN-only** —
  home-server. `:28981` is admitted on `wg0` only and deliberately *not* given an
  NPM proxy host, so unlike Forgejo it has no WAN surface: a paper archive is the
  one service here with no reason to be public. All of it — database, search
  index, media and the nightly `document_exporter` — lives on the ZFS pool, not
  split SSD/pool like Forgejo, because the documents are irreplaceable and the
  workload isn't latency-bound. The consumption folder sits inside the NFS export
  (`/hdd_pool_1/share/paperless-inbox`) so any client that mounts the share has a
  drop folder. `/hdd_pool_1/services` is therefore `root:root 0755`: three
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
