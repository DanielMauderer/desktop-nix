# 05 — Theming strategy (matugen vs stylix)

- **Status:** done
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

**Outcome: Stylix chosen (not matugen). See [DECISIONS 022](../DECISIONS.md).**

## Sub-tasks

- [x] **Decision spike:** evaluated matugen vs stylix → **Stylix**
      (`modules/nixos/desktop/theming.nix`); recorded in DECISIONS 022.
      Wallpaper-change-equals-rebuild accepted.
- [x] Implement the chosen pipeline for hyprland colors, waybar, rofi, wlogout,
      swaylock (kitty config is Ticket 06 — stylix's kitty target themes it
      automatically once enabled). dunst replaced by **swaync** (DECISIONS 022).
      waybar/wlogout/rofi/hyprland keep their Ticket-04 layouts and source
      colours from `config.lib.stylix.colors`; their stylix targets are disabled.
- [x] GTK 3/4 + icon theme (Papirus via `stylix.icons`) + cursor (Bibata via
      `stylix.cursor`); Qt via `stylix.targets.qt.platform = "qtct"` (stylix's
      default; themes Qt through a generated Kvantum theme).
- [x] Wallpaper flow: `stylix.image` (a committed default
      `modules/nixos/desktop/wallpaper.png`); picker
      `pkgs/scripts/theme-wallpaper-select.sh` (SUPER+W) repaints live with
      swaybg + rebuilds to recolour; swaylock picks up the wallpaper via stylix.
      The old `~/.config/hypr/cache/` path is gone.
- [x] matugen not kept — `apply_matugen.sh` + the `matugen/templates/` engine
      are dropped (the inline-bash generators were already dead code).
- [x] Kill-based reloads retired: dunst's `pkill dunst; dunst &` is gone with
      dunst itself (swaync owns its user service); waybar already used
      `pkill -USR2` / `systemd.enable`.

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

- [x] **Matugen vs stylix** — resolved: **Stylix** (DECISIONS 022). Not hybrid.
- [x] dunst include mechanism — moot: dunst replaced by **swaync**, themed by
      stylix's swaync target.
- [x] Live re-theming vs rebuild — rebuild accepted; the picker gives an instant
      swaybg preview to soften the rebuild latency.

## Ask when starting

- `matugen/templates/*.tmpl` + `config.toml` exist but `apply_matugen.sh`
  duplicates all of it in inline bash — the templates are currently dead
  code. Confirm which of the two is the source of truth today (bash version
  appears to be) before porting.
- Generated swaylock config embeds an absolute wallpaper path — confirm
  swaylock should reference the state-dir path instead.
- `papirus-icon-theme` was layered system-wide on maudiblue — confirm Papirus
  stays the icon theme.
