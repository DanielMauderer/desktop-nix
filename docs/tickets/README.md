# Tickets

Migration tickets, numbered in rough execution order. See
[ROADMAP.md](../ROADMAP.md) for phases and the dependency graph.

## Convention

- File: `NN-kebab-slug.md`
- Header fields: `Status` (open / in-progress / blocked / done),
  `Depends on`, `Machines`

> **When completing a ticket:** update `Status` in *both* the individual
> ticket file **and** the index table below. Updating only one causes the
> next agent to pick up the same ticket as if it were still open.

- Fixed sections in every ticket:
  - **Goal** — what done looks like
  - **Sub-tasks** — checklist
  - **Testing** — mandatory checklist; the [baseline](../ROADMAP.md#testing-principle-applies-to-every-ticket)
    (flake check, linters, all host builds, CI green) plus ticket-specific tests
  - **Open questions** — decisions to make during the ticket; record outcomes
    in [DECISIONS.md](../DECISIONS.md)
  - **Ask when starting** — issues found in the old config that need a user
    decision before porting (don't migrate bugs)

## Index

| # | Ticket | Phase | Depends on | Machines | Status |
|---|---|---|---|---|---|
| 01 | [Repo bootstrap: flake skeleton](01-repo-bootstrap-flake-skeleton.md) | 1 | — | all | done |
| 02 | [Testing & CI infrastructure](02-testing-and-ci-infrastructure.md) | 1 | 01 | all | done |
| 03 | [Base system module](03-base-system-module.md) | 2 | 01, 02 | all | open |
| 04 | [Hyprland desktop stack](04-hyprland-desktop-stack.md) | 2 | 03 | all | open |
| 05 | [Theming strategy (matugen vs stylix)](05-theming-strategy.md) | 2 | 04 | all | open |
| 06 | [Shell & CLI environment](06-shell-and-cli-environment.md) | 2 | 03 | all | open |
| 07 | [Neovim](07-neovim.md) | 2 | 06 | all | open |
| 08 | [Dev environment (replaces toolbox)](08-dev-environment.md) | 2 | 03, 06 | desktop, work-laptop (light: private-laptop) | open |
| 09 | [Virtualisation: libvirt/KVM](09-virtualisation-libvirt.md) | 2 | 03 | desktop, work-laptop (TBD) | open |
| 10 | [Flatpak strategy](10-flatpak-strategy.md) | 2 | 03 | all | open |
| 11 | [Gaming & CachyOS kernel](11-gaming-and-cachyos-kernel.md) | 2 | 03 (04 for gamemode bind) | desktop | open |
| 12 | [Secrets management](12-secrets-management.md) | 2 | 01 | all | open |
| 13 | [Host: private-laptop (PILOT)](13-host-private-laptop-pilot.md) | 3 | 03–07, 10 | private-laptop | open |
| 14 | [Host: work-laptop](14-host-work-laptop.md) | 3 | 08, 09, 12, 13 | work-laptop | open |
| 15 | [Host: desktop](15-host-desktop.md) | 3 | 08, 09, 11, 13 | desktop | open |
| 16 | [Waydroid](16-waydroid.md) | 2 | 03 | TBD (maybe drop) | open |
| 17 | [Archive old repos](17-archive-old-repos.md) | 4 | 13, 14, 15 | — | open |
