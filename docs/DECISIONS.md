# Architecture decisions

The key choices behind this config and why, one line each. The reasoning that
matters lives here; the rest is in the Nix code and `git log`.

## Structure
- **Plain flake, no flake-parts** — three hosts don't justify the abstraction; a
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
- **disko-declared disks.** Laptops: **LUKS2 + ext4 + zram**. Desktop: **plain
  ext4, no LUKS** (at home — different physical-security profile, no passphrase
  at every boot). home-server: SSD root + ZFS data pool.
- **sops-nix secrets.** Each host decrypts with its SSH host ed25519 key
  converted to age; a personal master age key (private half in the password
  manager) is a recipient on every secret for recovery/re-keying. Scheme and
  enrollment steps live in `modules/nixos/core/README.md`.

## Theming
- **stylix** derives the palette from `modules/nixos/desktop/wallpaper.png` at
  build time. waybar/wlogout/rofi/hyprland keep custom layouts and read colours
  from `config.lib.stylix.colors`.
- **waybar media via a playerctl script, not the built-in `mpris` module** — the
  C++ module intermittently crashed the whole bar on D-Bus metadata changes; the
  `waybar-mpris` wrapper escapes markup and never exits non-zero.
- **gsimplecal for the waybar calendar** — the clock's `on-click` opens the GTK
  popup (themed by stylix) instead of an unstyled `{calendar}` tooltip.

## Updates
- **Daily `system.autoUpgrade`** (`allowReboot = false`) from the committed
  `flake.lock`; CI bumps the lock (`update-lock.yml`).
- **work-laptop tracks the CI-gated `release` branch**; pilot + desktop track
  `main`. Promotion model: `modules/nixos/core/README.md`.
- **First-login password**: hosts ship a hashed throwaway password, force-expired
  once at first activation so `maudi` must set a real one.

## Per-host opt-ins
- **gaming** (CachyOS, Steam, AMD GPU) — desktop only.
- **waydroid** (Android container) — private-laptop + desktop; never work-laptop.
- **server** (WireGuard server, SSH-over-VPN, ZFS, NFS) — home-server only.
- **work-laptop hardening** — release channel, longer auto-suspend (30 min),
  WireGuard client + sops; no gaming, no waydroid (policy-bound machine).
