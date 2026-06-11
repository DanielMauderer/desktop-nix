# 02 — Testing & CI infrastructure

- **Status:** open
- **Depends on:** 01
- **Machines:** all

## Goal

**The key ticket of the migration:** every later ticket gets automatic
verification. CI proves on every push that the flake is healthy, lint-clean,
and that *all three host configurations build*. A `nixosTest` template
establishes the pattern for VM-level tests that later tickets extend. After
this ticket, "it builds in CI + its tests pass" is the definition of done
everywhere.

## Sub-tasks

- [ ] GitHub Actions workflow: install nix (e.g. `DeterminateSystems/nix-installer-action`),
      run `nix flake check -L` on push/PR
- [ ] Build matrix job over the three hosts:
      `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`
- [ ] Lint jobs: `nix fmt -- --check .`, `statix check`, `deadnix --fail`
- [ ] Wire linters into the flake's `checks.` output so local
      `nix flake check` == CI (no drift between local and CI checks)
- [ ] Binary cache for CI speed: magic-nix-cache / cachix (decision below);
      pre-configure the chaotic-nyx cache for when Ticket 11 lands
- [ ] First `nixosTest` as a template under `checks.`: boot a host config in a
      VM, assert it reaches `multi-user.target` — later tickets copy this
      pattern (e.g. assert the Hyprland session unit exists, libvirtd active)
- [ ] Document the local pre-push routine in `docs/` (one command: `nix flake check`)
- [ ] Optional: pre-commit hooks (git-hooks.nix) for format/lint — decide below

## Testing

- [ ] Baseline: `nix flake check` green, linters clean, all host builds pass, CI green
- [ ] Negative test: open a PR with a deliberate syntax error → CI goes red;
      fix → green (proves the pipeline actually gates)
- [ ] Second CI run is measurably faster (cache hit verified)
- [ ] The template `nixosTest` runs both locally (`nix build .#checks...`) and in CI

## Open questions

- [ ] Cache: magic-nix-cache (zero setup, GitHub-hosted) vs cachix (works
      everywhere incl. local machines)? Free-tier limits?
- [ ] GitHub-hosted runner disk (~14 GB) vs three toplevel builds — split into
      matrix jobs per host (recommended) or use a space-reclaim action?
- [ ] Pre-commit hooks: enforce locally or rely on CI only?
- [ ] How far to take `nixosTest` for graphical stuff — Hyprland can start
      headless in a VM, but is asserting "session unit active" enough per ticket?

## Ask when starting

- The old setup had zero automated testing (BlueBuild only built the image).
  Confirm the testing bar above is the desired level — it gates every
  subsequent ticket.
