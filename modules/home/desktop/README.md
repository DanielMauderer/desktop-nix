# desktop

The per-user Hyprland desktop (home-manager) — wired in by the NixOS
`modules/nixos/desktop` module. Colours come from stylix; waybar/wlogout/rofi/
hyprland keep their custom layouts and read `config.lib.stylix.colors`.

| File            | Configures                                                     |
|-----------------|---------------------------------------------------------------|
| `hyprland.nix`  | Hyprland settings: keybinds, window rules, workspaces.        |
| `waybar.nix`    | waybar (+ `waybar-style.css`); media via the `waybar-mpris` script, calendar via gsimplecal. |
| `swaync.nix`    | swaync notification daemon + control center.                  |
| `rofi.nix`      | rofi launcher (+ `rofi-theme.rasi`).                          |
| `wlogout.nix`   | wlogout power menu (+ `wlogout-style.css`).                   |
| `lockscreen.nix`| swaylock + swayidle (5-min lock; auto-suspend overridden per host). |
| `kanshi.nix`    | Monitor profiles; the `laptop-internal` fallback (host profiles prepend). |
| `packages.nix`  | Desktop user packages.                                        |

The packaged hypr/waybar scripts (`pkgs/`) are passed to these files via the
`desktopScripts` module arg.
