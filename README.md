# desktop-nix

Declarative NixOS configuration for all my machines — replacing the previous
Fedora Silverblue setup ([maudiblue](https://github.com/DanielMauderer/maudiblue)
BlueBuild image + [MyLinux](https://github.com/DanielMauderer/MyLinux) dotfiles),
which will be archived once the migration is complete.

Desktop environment: **Hyprland** (Wayland) with Material You dynamic theming.

## Machines

| Host             | Role                              | GPU              | Kernel            | Special modules                     |
|------------------|-----------------------------------|------------------|-------------------|-------------------------------------|
| `private-laptop` | Media consumption, some dev       | Intel/AMD iGPU   | default           | — (**pilot: migrates first**)       |
| `work-laptop`    | Heavy development                 | Intel/AMD iGPU   | default           | full dev stack, libvirt, wireguard  |
| `desktop`        | Gaming + development              | AMD dGPU         | **CachyOS** (chaotic-nyx) | gaming (steam, scx, gamemode), libvirt |

## Repository layout

```
docs/        Documentation: ROADMAP, DECISIONS, INVENTORY, runbooks, tickets
hosts/       Per-host configuration (one dir per machine + hardware config)
modules/     Reusable modules — modules/nixos (system) and modules/home (home-manager)
lib/         Helper functions (mkHost etc.)
overlays/    Nixpkgs overlays (patches only — external package sets are flake inputs)
pkgs/        Custom packages (e.g. scripts packaged with writeShellApplication)
```

## Architecture (summary — see [docs/DECISIONS.md](docs/DECISIONS.md))

- **Flakes**, plain (no flake-parts) — `flake.nix` is created in
  [Ticket 01](docs/tickets/01-repo-bootstrap-flake-skeleton.md)
- **home-manager as a NixOS module** — one `nixos-rebuild switch` updates
  system + home atomically
- **CachyOS kernel** via the [chaotic-cx/nyx](https://github.com/chaotic-cx/nyx)
  flake input on the desktop host only
- **Testing is mandatory** — every ticket has a Testing checklist; CI builds all
  host configurations on every push (see
  [Ticket 02](docs/tickets/02-testing-and-ci-infrastructure.md))

## Status

| Ticket | Description | Status |
|--------|-------------|--------|
| [01](docs/tickets/01-repo-bootstrap-flake-skeleton.md) | Repo bootstrap: flake skeleton | ✅ done |
| [02](docs/tickets/02-testing-and-ci-infrastructure.md) | Testing & CI infrastructure | open |
| 03–17 | Modules, hosts, archive | open |

**Next step:** run `nix flake update` locally after pulling to generate
`flake.lock`, then verify with `nix flake check` and
`nix build .#nixosConfigurations.<host>.config.system.build.toplevel`.

- Migration plan & phases: [docs/ROADMAP.md](docs/ROADMAP.md)
- Ticket index: [docs/tickets/README.md](docs/tickets/README.md)
- Architecture decisions: [docs/DECISIONS.md](docs/DECISIONS.md)
- What's being migrated: [docs/INVENTORY.md](docs/INVENTORY.md)
