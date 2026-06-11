# 05 — Theming strategy (matugen vs stylix)

- **Status:** open
- **Depends on:** 04
- **Machines:** all

## Goal

One decided, documented theming pipeline that produces Material You colors
from the current wallpaper for **all** themed apps (hyprland, waybar, kitty,
dunst, rofi, wlogout, swaylock, GTK 3/4, Qt via Kvantum/qt5ct/qt6ct) and is
compatible with home-manager's read-only symlinks. This is the **biggest
architectural decision** of the desktop migration — the current pipeline
writes generated files straight into `~/.config/*` at runtime, which breaks
when those paths are HM-managed store symlinks.

## Sub-tasks

- [ ] **Decision spike:** evaluate the two candidate architectures and record
      the choice in DECISIONS.md:
      1. **Keep matugen:** matugen writes generated color files to
         `$XDG_STATE_HOME/theme/`; static HM-managed configs `include` /
         `@import` / `source=` those paths (kitty `include`, waybar/wlogout
         CSS `@import`, hyprland `source=`, rofi `@import`); wallpaper changes
         re-theme without a rebuild
      2. **Stylix:** declarative theming from a wallpaper input at build time;
         wallpaper changes require `nixos-rebuild switch`; less custom glue,
         but less "live"
- [ ] Implement the chosen pipeline for: hyprland colors, waybar, kitty,
      dunst, rofi, wlogout, swaylock
- [ ] GTK 3/4 + icon theme (papirus) + cursor; Qt: Kvantum/qt5ct/qt6ct or
      `qt.platformTheme` — make Qt apps follow the palette
- [ ] Wallpaper flow: where the current wallpaper lives (move out of
      `~/.config/hypr/cache/` into `$XDG_STATE_HOME` or `$XDG_CACHE_HOME`),
      wallpaper-picker script, swaybg/swaylock pick it up
- [ ] If matugen is kept: rewrite `apply_matugen.sh` to actually use the
      `matugen/templates/` + `config.toml` engine (delete the duplicated
      inline-bash generation), package it via `writeShellApplication`
- [ ] Replace kill-based reloads (`pkill dunst; dunst &`) with proper ones
      (`systemctl --user reload/restart`, `pkill -USR2 waybar`, kitty remote
      control)

## Testing

- [ ] Baseline: flake check, linters, all host builds, CI green
- [ ] HM activation succeeds with no writes into store paths (negative test:
      theming script must fail loudly if it tries to write an HM-managed file)
- [ ] `nixosTest` (matugen variant): run the apply script against a fixture
      wallpaper in a VM → all expected generated files exist in the state dir
      and referenced includes resolve
- [ ] Manual on hardware: change wallpaper → kitty, waybar, dunst, rofi, GTK
      app, Qt app all re-theme; swaylock shows wallpaper + palette
- [ ] Second wallpaper change works (idempotency / no stale state)

## Open questions

- [ ] **Matugen vs stylix** — the core decision. Hybrid possible (stylix for
      GTK/Qt base, matugen for the live Wayland apps)?
- [ ] dunst has no include mechanism for `dunstrc` — options: dunst's
      drop-in dir (`dunstrc.d`), full-file generation into a writable path
      with HM only providing the base, or stylix-managed
- [ ] Does live re-theming without rebuild actually matter to you, or is
      wallpaper-change-equals-rebuild acceptable? (Decides 80 % of the above.)

## Ask when starting

- `matugen/templates/*.tmpl` + `config.toml` exist but `apply_matugen.sh`
  duplicates all of it in inline bash — the templates are currently dead
  code. Confirm which of the two is the source of truth today (bash version
  appears to be) before porting.
- Generated swaylock config embeds an absolute wallpaper path — confirm
  swaylock should reference the state-dir path instead.
- `papirus-icon-theme` was layered system-wide on maudiblue — confirm Papirus
  stays the icon theme.
