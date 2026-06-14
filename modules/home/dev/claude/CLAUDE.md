# Personal Context

## User
- Name: Daniel Mauderer
- Role: Software developer

## System
- OS: NixOS (declarative — the whole system + home is the flake in `~/desktop-nix`)
- Desktop: Hyprland on Wayland
- Shell: Fish
- Terminal: Kitty

## Package Management
- The system and user environment are **declarative**. Do NOT suggest `dnf`,
  `rpm-ostree`, `brew`, or `toolbox` — none of them exist on this machine.
- System packages: add to the relevant module under `~/desktop-nix/modules/nixos/`,
  then `sudo nixos-rebuild switch --flake ~/desktop-nix` (the `update` alias).
- User CLI tools: home-manager modules under `~/desktop-nix/modules/home/`.
- Per-project toolchains: Nix devShells + direnv. Scaffold one with
  `nix flake init -t ~/desktop-nix#<rust|go|node|python>` then `direnv allow`.
- GUI apps: Flatpak (`flatpak install`).

## Dev Environment
- Editor: Neovim (config in `~/.config/nvim/` → `~/desktop-nix/nvim/`, lazy.nvim)
- Version control UI: Neogit / fugitive inside Neovim; lazygit (`lg`)
- Rust watcher: `bacon` (run in a split or via the `cw` alias)
- Containers: Podman (aliased as `docker`)
- Primary language: Rust

## Workflow Preferences
- Keep suggestions concise — no hand-holding on standard tools
- Prefer Fish-compatible shell syntax in examples
- When suggesting new tools, add them declaratively (a project devShell or a
  home-manager module) rather than installing imperatively
