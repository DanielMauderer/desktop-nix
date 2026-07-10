# desktop

The per-user Hyprland desktop (home-manager) — wired in by the NixOS
`modules/nixos/desktop` module. Colours come from stylix; the Noctalia shell
colours its own UI from the same wallpaper, while hyprland keeps its custom
gradient borders read from `config.lib.stylix.colors`.

| File            | Configures                                                     |
|-----------------|---------------------------------------------------------------|
| `hyprland.nix`  | Hyprland settings: keybinds (Noctalia IPC), window rules, workspaces. |
| `noctalia.nix`  | Noctalia shell: bar, launcher, notifications, control center, OSD, lock screen, wallpaper, session menu, idle → auto-lock/suspend. Replaces waybar/rofi/swaync/swaylock/swayidle/swaybg/wlogout. |
| `kanshi.nix`    | Monitor profiles; the `laptop-internal` fallback (host profiles prepend). |
| `packages.nix`  | Desktop user packages.                                        |

The packaged hypr scripts (`pkgs/`) are passed to these files via the
`desktopScripts` module arg.
