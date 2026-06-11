# Migration Roadmap: Fedora Silverblue → NixOS

Goal: all three machines on NixOS, configured from this repo; then archive
[maudiblue](https://github.com/DanielMauderer/maudiblue) and
[MyLinux](https://github.com/DanielMauderer/MyLinux).

Machine order: **private-laptop (pilot) → work-laptop → desktop**
(see [DECISIONS.md](DECISIONS.md) #004).

## Phases

### Phase 1 — Infrastructure (Tickets 01–02)
Flake skeleton that evaluates and builds three (empty) host configs, plus the
testing/CI foundation. **Nothing else starts before CI can prove a change
builds for all hosts.** Ticket 12 (secrets) can also start any time after 01.

### Phase 2 — Modules (Tickets 03–12, 16)
Port everything from maudiblue + MyLinux into reusable modules: base system,
Hyprland desktop, theming, shell, neovim, dev environment, virtualisation,
flatpaks, gaming/CachyOS, secrets, waydroid. Each ticket lands with tests
(flake checks, host builds, nixosTest VM tests where possible).

### Phase 3 — Hosts & migration (Tickets 13–15)
Compose the per-host configs, write an install/migration runbook per machine,
install for real. Pilot lessons from the private laptop flow back into the
modules before the work laptop and desktop follow.

### Phase 4 — Archive (Ticket 17)
Parity sweep against [INVENTORY.md](INVENTORY.md), archive the old repos,
disable the BlueBuild image builds.

## Ticket dependency graph

```
01 bootstrap ──► 02 testing/CI ──► 03 base ──┬─► 04 hyprland ──► 05 theming
      │                                      ├─► 06 shell ─────► 07 neovim
      └────────► 12 secrets                  ├─► 08 dev (also needs 06)
                                             ├─► 09 libvirt
                                             ├─► 10 flatpak
                                             ├─► 11 gaming/cachyos (04 for gamemode bind)
                                             └─► 16 waydroid

03,04,05,06,07,10 ──► 13 private-laptop (PILOT)
13 + 08,09,12     ──► 14 work-laptop
13 + 08,09,11     ──► 15 desktop
13,14,15          ──► 17 archive old repos
```

Tickets within Phase 2 are largely parallelisable once 03 is done.

## Testing principle (applies to every ticket)

Defined in detail in [Ticket 02](tickets/02-testing-and-ci-infrastructure.md).
Minimum bar for *every* ticket before it is `done`:

1. `nix flake check` passes
2. `nixfmt --check` / `statix` / `deadnix` clean
3. All three host toplevels build:
   `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`
4. CI green on the branch
5. Ticket-specific checks: `nixosTest` VM tests where the feature is testable
   headlessly, otherwise a written manual verification checklist executed on
   real hardware

## Ticket index

See [tickets/README.md](tickets/README.md).
