# 04 — Hyprland desktop stack

- **Status:** done
- **Depends on:** 03
- **Machines:** all

## Goal

Hyprland session as a NixOS module (session registration, greeter, XDG
portals, polkit agent) plus home-manager modules porting the MyLinux config
dirs: `hypr/`, `waybar/`, `dunst/`, `rofi/`, `wlogout/`, swaylock/swayidle/
swaybg, hyprshot. The runtime-mutation patterns (monitor hotplug, focus mode)
are redesigned to be compatible with read-only HM-managed config.

## Sub-tasks

- [x] NixOS side: `programs.hyprland.enable` (upstream flake), greeter (greetd +
      tuigreet — DECISIONS 015), `xdg.portal` (hyprland + gtk), polkit agent
      (hyprpolkitagent — DECISIONS 018), polkit/dconf prerequisites.
      `modules/nixos/desktop/`
- [x] HM: ported `hypr/hyprland.conf` + modular `conf/` files into native
      `wayland.windowManager.hyprland.settings` (DECISIONS 019).
      `modules/home/desktop/hyprland.nix`
- [x] HM: waybar (native settings + style.css), dunst, rofi, wlogout, swaylock,
      swayidle, swaybg, hyprshot (nixpkgs). `modules/home/desktop/`
- [x] Packaged the surviving `hypr/scripts/*` and `waybar/scripts/*` into
      `pkgs/` with `writeShellApplication` (shellcheck at build); obsolete
      scripts dropped (see `pkgs/default.nix` header)
- [x] **Monitor layout redesign:** kanshi profiles (DECISIONS 017) replace the
      `monitor-hotplug.sh`/`switch_hypr_env.sh` cycle. `modules/home/desktop/kanshi.nix`.
      Per-host workspace→monitor rules land in Tickets 13–15
- [x] **Focus mode redesign:** reimplemented with `hyprctl keyword` (no file
      writes). `pkgs/scripts/hypr-focus-mode.sh`
- [x] Moved `{focusmode,gamemode}-enabled` flags to
      `$XDG_STATE_HOME/desktop-nix/` (ml4w namespace retired — DECISIONS 020)
- [x] Keybindings parity: ported `keybindings/default.conf` verbatim (lock
      standardised on swaylock — DECISIONS 016; dead `$SCRIPTS` var dropped;
      SUPER+SHIFT+= monitor toggle dropped in favour of kanshi)

## Testing

- [x] Baseline: linters (statix/deadnix/nixfmt) clean; all three host configs
      evaluate; `checks.x86_64-linux.test-desktop` evaluates. Full host builds /
      VM-test build left to CI (magic-nix-cache).
- [~] `nixosTest` (`test-desktop`): asserts greetd active, Hyprland binary
      installed, power-profiles-daemon active, and the maudi home generation
      (waybar, swaylock, hyprpolkitagent unit, rendered `hyprland.conf`). The
      deeper headless-launch + `hyprctl monitors` assertion is left as a
      follow-up (DECISIONS 010 allows incremental graphical assertions).
- [x] Packaged scripts pass shellcheck at build time (writeShellApplication —
      all 8 built successfully)
- [ ] HM activation idempotent: second `nixos-rebuild switch` changes nothing
      (verify on hardware)
- [ ] Manual on hardware (pilot): dock/undock monitor switch, focus mode
      toggle, screenshot to clipboard, lock screen, notifications

## Open questions

- [x] Greeter: **greetd + tuigreet** (DECISIONS 015).
- [x] Monitor handling on work-laptop: **kanshi autodetection** (DECISIONS 017).
- [x] Config as files vs native HM settings: **native settings** (DECISIONS 019).
- [x] Polkit agent: **hyprpolkitagent** (DECISIONS 018).

## Ask when starting

- `$SCRIPTS = ~/.config/ml4w/scripts` in `keybindings/default.conf` is dead
  (never used; all binds use `$HYPRSCRIPTS`) — **confirmed dropped.**
- `setup.sh` symlinks a `swaybg/` dir that doesn't exist in MyLinux —
  **confirmed: no missing config.** swaybg is launched from the Hyprland
  exec-once (no config dir); wallpaper path is Ticket 05.
- The `ml4w` naming is a leftover from the ML4W dotfiles — **confirmed
  rename** to `$XDG_STATE_HOME/desktop-nix` (DECISIONS 020).
- Wallpaper path `~/.config/hypr/cache/current_wallpaper.png` — the exec-once
  points there; the wallpaper/cache design is Ticket 05.

## Notes / follow-ups for later tickets

- **Ticket 05 (theming):** static fallback colours are inlined in
  `hyprland.nix` (`$primary` etc.), `waybar-style.css`, `rofi-theme.rasi` and
  `wlogout-style.css`. These are the seams matugen must override (preferably
  via a writable `$XDG_STATE_HOME` file sourced/imported at runtime).
- **Tickets 13–15 (hosts):** kanshi output names/modes are best-effort from the
  old `.conf` files and need on-hardware verification; per-host
  workspace→monitor rules are added there.
- The work-laptop temperature waybar module dropped its hardcoded
  `thermal-zone`/`hwmon-path` (host-specific); revisit per host if needed.
