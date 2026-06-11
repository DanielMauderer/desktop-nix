# 04 — Hyprland desktop stack

- **Status:** open
- **Depends on:** 03
- **Machines:** all

## Goal

Hyprland session as a NixOS module (session registration, greeter, XDG
portals, polkit agent) plus home-manager modules porting the MyLinux config
dirs: `hypr/`, `waybar/`, `dunst/`, `rofi/`, `wlogout/`, swaylock/swayidle/
swaybg, hyprshot. The runtime-mutation patterns (monitor hotplug, focus mode)
are redesigned to be compatible with read-only HM-managed config.

## Sub-tasks

- [ ] NixOS side: `programs.hyprland.enable`, greeter (greetd + tuigreet?),
      `xdg.portal` (hyprland portal), polkit agent (lxqt-policykit or
      hyprpolkitagent — decide), seat/session prerequisites
- [ ] HM: port `hypr/hyprland.conf` + modular `conf/` files (keybindings,
      decoration, animation, windowrule, autostart) — keep the existing
      modular file structure via `xdg.configFile` or translate to
      `wayland.windowManager.hyprland.settings` (decide; recommendation: keep
      files initially, translate incrementally)
- [ ] HM: waybar (config.jsonc + modules/ + layouts/ + style.css), dunst,
      rofi, wlogout, swaylock, swayidle, swaybg, hyprshot (nixpkgs package
      replaces the git-clone install from setup.sh)
- [ ] Package the `hypr/scripts/*` and `waybar/scripts/*` shell scripts into
      `pkgs/` with `writeShellApplication` (explicit runtime deps, shellcheck
      at build time); drop scripts made obsolete by the redesigns below
- [ ] **Monitor layout redesign:** per-host monitor/workspace config from
      `hosts/<name>/` (layouts are known per machine: `w_laptop*`, `p_laptop`,
      desktop `default`) — replaces `monitor-hotplug.sh` cycling; evaluate
      kanshi/shikane for the work-laptop dock/undock case
- [ ] **Focus mode redesign:** `focus-mode.sh` currently rewrites
      `focus-mode-rules.conf` inside the config dir — move generated rules to
      a writable path (`$XDG_STATE_HOME`) `source=`d by the static hyprland
      config, or reimplement with `hyprctl keyword` (no file writes)
- [ ] Move `~/.config/ml4w/settings/{focusmode,gamemode}-enabled` flags to
      `$XDG_STATE_HOME/desktop-nix/` (and rename the ml4w namespace)
- [ ] Keybindings parity check against `hypr/conf/keybindings/default.conf`
      (SUPER+RETURN kitty, SUPER+SPACE rofi, SUPER+L lock, SUPER+S hyprshot,
      SUPER+Z focus mode, …)

## Testing

- [ ] Baseline: flake check, linters, all host builds, CI green
- [ ] `nixosTest`: VM boots to greeter; Hyprland session starts headless
      (`WLR_BACKEND=headless`/`Aquamarine` headless) and `hyprctl monitors`
      responds; waybar + dunst units active in the user session
- [ ] Packaged scripts pass shellcheck at build time (writeShellApplication)
- [ ] HM activation idempotent: second `nixos-rebuild switch` changes nothing
- [ ] Manual on hardware (pilot): dock/undock monitor switch, focus mode
      toggle, screenshot to clipboard, lock screen, notifications

## Open questions

- [ ] Greeter: greetd+tuigreet vs SDDM vs autologin-to-Hyprland?
- [ ] Monitor handling on work-laptop: kanshi-style autodetection (recommended)
      vs keeping a manual toggle keybind?
- [ ] Keep config as files (`xdg.configFile`) vs native HM
      `wayland.windowManager.hyprland.settings`? Affects how Ticket 05 injects
      colors.
- [ ] Polkit agent: stick with lxqt-policykit or switch to hyprpolkitagent?

## Ask when starting

- `$SCRIPTS = ~/.config/ml4w/scripts` in `keybindings/default.conf` is dead
  (never used; all binds use `$HYPRSCRIPTS`) — confirm drop.
- `setup.sh` symlinks a `swaybg/` dir that doesn't exist in MyLinux — confirm
  there's no missing config that lived only on a machine.
- The `ml4w` naming is a leftover from the ML4W dotfiles the repo was based
  on — confirm renaming the state dir is fine.
- Wallpaper path `~/.config/hypr/cache/current_wallpaper.png` is hardcoded in
  `hyprland.conf` — the wallpaper/cache design moves to Ticket 05; this ticket
  only needs the `exec-once` to point at the path Ticket 05 defines.
