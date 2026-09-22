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
- Per-project toolchains: **always** a Nix devShell + direnv, never a global
  install. Add a `flake.nix` with the toolchain in `mkShell` and an `.envrc`
  containing `use flake`, then `direnv allow`. Nothing language-specific
  (cargo, go, node, python, cc) is on the global PATH — by design, so a
  project's pinned version can never be shadowed.

## Dev Environment
- Editor: Neovim (configured declaratively with nixvim in `modules/home/neovim/`)
- Version control UI: Neogit / fugitive inside Neovim; lazygit (`lg`); jj +
  jjui (`lj`) for stacked branches
- Containers: Podman (aliased as `docker`)
- Primary language: Rust

## Workflow Preferences
- Keep suggestions concise — no hand-holding on standard tools
- Prefer Fish-compatible shell syntax in examples
- When suggesting new tools, add them declaratively (a project devShell or a
  home-manager module) rather than installing imperatively
