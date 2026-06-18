# desktop-nix

Declarative NixOS configuration for all my machines. Desktop environment:
**Hyprland** (Wayland) with stylix-driven dynamic theming. home-manager runs as
a NixOS module, so one `nixos-rebuild switch` updates system and home together.

## Machines

| Host             | Role                         | GPU            | Kernel             | Notes                                  |
|------------------|------------------------------|----------------|--------------------|----------------------------------------|
| `private-laptop` | Media + light dev            | Intel iGPU     | default            | pilot; LUKS; waydroid                  |
| `work-laptop`    | Heavy dev                    | Intel iGPU     | default            | LUKS; wireguard; CI-gated `release` channel |
| `desktop`        | Gaming + dev                 | AMD dGPU       | **CachyOS** (chaotic-nyx) | gaming stack; ext4 no-LUKS; waydroid |
| `home-server`    | Headless services            | —              | LTS                | ZFS, NFS, WireGuard server, no GUI     |

Each host has its own docs: `hosts/<name>/README.md` (what the machine is) and
`hosts/<name>/INSTALL.md` (how to install it).

## Repository layout

```
hosts/<name>/    Per-host config + README (description) + INSTALL (install guide)
modules/nixos/   System modules, one README per group (base, core, desktop, …)
modules/home/    home-manager modules, one README per group (cli, desktop, dev, neovim)
lib/             mkHost.nix — the nixosConfiguration factory
overlays/        Nixpkgs overlays (local patches only)
pkgs/            Custom packages (shell scripts via writeShellApplication)
scripts/         install.sh — scripted host installer
docs/            DECISIONS.md — the key architecture choices
```

## Local development

```sh
nix develop                 # dev shell with lint/format tools
nix flake check -L          # everything CI runs (eval + per-host build + nixosTests)
nix fmt                     # format all .nix files
nix build .#nixosConfigurations.<host>.config.system.build.toplevel -L
```

## Documentation map

- **Per host** — `hosts/<name>/README.md` + `hosts/<name>/INSTALL.md`
- **Per module group** — `README.md` in each `modules/nixos/*` and `modules/home/*` dir
- **Architecture decisions** — [docs/DECISIONS.md](docs/DECISIONS.md)
- **Secrets & update automation** — [modules/nixos/core/README.md](modules/nixos/core/README.md)
