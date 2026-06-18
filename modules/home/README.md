# modules/home/

home-manager modules (used as NixOS modules, not standalone). Each group has its
own README.

| Group     | What it configures                                                  |
|-----------|---------------------------------------------------------------------|
| `cli`     | Shell environment: fish + starship, kitty, fastfetch, lazygit, CLI tools. All hosts. |
| `desktop` | Per-user Hyprland/waybar/swaync/rofi/wlogout/lockscreen/kanshi + stylix. Workstations. |
| `dev`     | Language toolchains (Rust/Go/Node/Python/C), direnv, the Claude config. |
| `neovim`  | Neovim with the lazy.nvim config under `nvim/` + LSP/formatter/DAP packages. |
