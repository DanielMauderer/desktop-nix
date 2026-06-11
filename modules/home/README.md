# modules/home/

home-manager modules (used as a NixOS module, not standalone). These replace
the symlinked config dirs from the MyLinux dotfiles repo. Planned modules and
the tickets that create them:

| Module                                   | Replaces (MyLinux)                       | Ticket |
|------------------------------------------|------------------------------------------|--------|
| `hyprland` (+ waybar, dunst, rofi, wlogout, swaylock/-idle/-bg, hyprshot) | `hypr/`, `waybar/`, `dunst/`, `rofi/`, `wlogout/` | 04 |
| `theming` (matugen or stylix, gtk/qt/Kvantum) | `matugen/`, `gtk-3.0/`, `gtk-4.0/`, `Kvantum/`, `qt5ct/`, `qt6ct/` | 05 |
| `fish` (+ kitty, fastfetch, lazygit, CLI tools) | `fish/`, `kitty/`, `fastfetch/`, `lazygit/` | 06 |
| `neovim`                                  | `nvim/`                                  | 07     |
| `dev` (toolchains, direnv, claude config) | toolbox `dev-tools`, `claude/`           | 08     |
