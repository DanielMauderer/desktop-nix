# 17 — Archive old repos

- **Status:** open
- **Depends on:** 13, 14, 15 (all machines migrated)
- **Machines:** —

## Goal

Clean endpoint of the migration: prove nothing was lost, then archive
[maudiblue](https://github.com/DanielMauderer/maudiblue) and
[MyLinux](https://github.com/DanielMauderer/MyLinux).

## Sub-tasks

- [ ] **Parity sweep:** walk [INVENTORY.md](../INVENTORY.md) — every row must
      be `migrated` or `dropped` with a decision reference; no `open` rows
      remain
- [ ] Cross-check beyond the inventory: diff maudiblue `recipes/recipe.yml`
      package list and MyLinux `setup.sh` against the inventory one final
      time (catch anything added to the old repos *during* the migration)
- [ ] Sweep the last Silverblue install (or its backup) for imperative state:
      ad-hoc flatpaks, toolbox containers, `~/.local/bin`, crontabs/user units
- [ ] Add `ARCHIVED — superseded by desktop-nix` notice to both repos' READMEs
      with a link here
- [ ] Disable the maudiblue BlueBuild GitHub Action (daily image builds stop)
- [ ] Archive both repositories on GitHub (read-only)
- [ ] Remove firstboot/dotfiles-clone references from any remaining docs

## Testing

- [ ] Baseline: flake check, linters, all host builds, CI green (final state)
- [ ] The parity sweep itself is the test: INVENTORY.md has zero `open` rows;
      attach the final checked-off table to this ticket
- [ ] All three machines have been running NixOS as daily drivers for an
      agreed soak period (see open question) with no "I need something from
      the old setup" incidents
- [ ] maudiblue image build workflow confirmed disabled (no new images on
      ghcr.io)

## Open questions

- [ ] Soak period before archiving: 2 weeks? 1 month after the last machine?
- [ ] Keep the last maudiblue image tag on ghcr.io as an emergency-rollback
      artifact for N months, or delete?
- [ ] MyLinux has value as git history (config evolution) — archive preserves
      it; any reason to migrate history into desktop-nix instead? (Probably
      not — archive is enough.)

## Ask when starting

- Final confirmation before archiving — this is the point of no (easy) return
  for the old workflow.
