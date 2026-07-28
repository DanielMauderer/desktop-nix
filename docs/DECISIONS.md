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
- **A Noctalia bar widget surfaces update-source staleness** — it asks GitHub for
  the last commit on the tracked branch and turns red past `local.updateStaleDays`
  (3), so a stalled pipeline is visible. Remote check on purpose: a failed query
  is "offline", never "stale", so no network never looks like a broken pipeline.
- **First-login password**: hosts ship a hashed throwaway password, force-expired
  once at first activation so `maudi` must set a real one.

## Per-host opt-ins
- **gaming** (CachyOS, Steam, AMD GPU) — desktop only.
- **waydroid** (Android container) — private-laptop + desktop; never work-laptop.
- **server** (WireGuard server, SSH-over-VPN, ZFS, NFS) — home-server only.
- **Reverse proxy = Nginx Proxy Manager container** (UI-driven LE certs), not
  native `services.nginx`/`security.acme` — home-server only. Admin UI is
  published on the VPN address (`10.100.0.1:81`), not merely firewalled, because
  podman's port-publish DNAT bypasses the input-chain firewall. Containers run
  rootful-but-hardened (`no-new-privileges`); no service container ever mounts
  the podman/docker management socket.
- **net / home-server client** (`services.homeServerClient`) — desktop +
  private-laptop. WireGuard client of the server (split-tunnel, so `ssh
  home-server` works — server SSH is wg0-only) + `x-systemd.automount` NFS share.
  Desktop mounts over the LAN (no crypto on big files), the laptop over the VPN.
  `enable`-gated so an un-enrolled host (and keyless CI) still builds.
- **work-laptop hardening** — longer auto-suspend (30 min), WireGuard client +
  sops; no gaming, no waydroid (policy-bound machine).
