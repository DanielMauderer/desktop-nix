# desktop

The NixOS side of the Hyprland desktop — imported by every workstation host. The
per-user Hyprland/waybar/etc. config lives in `modules/home/desktop` and is wired
in by `./home.nix`.

| File          | Configures                                                       |
|---------------|-----------------------------------------------------------------|
| `hyprland.nix`| The Hyprland Wayland session (from the upstream flake), portals, polkit agent. |
| `greetd.nix`  | greetd greeter that launches the Hyprland session.              |
| `packages.nix`| System-level desktop packages.                                  |
| `theming.nix` | stylix — palette derived from `wallpaper.png` at build time.    |
| `home.nix`    | Wires the `modules/home/desktop` home-manager module for `maudi`. |
