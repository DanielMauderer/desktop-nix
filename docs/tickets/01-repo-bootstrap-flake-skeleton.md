# 01 — Repo bootstrap: flake skeleton

- **Status:** done
- **Depends on:** —
- **Machines:** all

## Goal

A minimal flake that evaluates and builds three empty-but-valid
`nixosConfigurations` (`private-laptop`, `work-laptop`, `desktop`). This is the
foundation every other ticket builds on — no real configuration yet, just the
structure, formatter, and dev tooling.

## Sub-tasks

- [x] `flake.nix` with inputs: `nixpkgs`, `home-manager` (channel decision below)
- [x] `lib/mkHost.nix` helper: host name + module list → `nixosConfiguration`,
      wires home-manager as a NixOS module (DECISIONS.md #002) and shared `specialArgs`
- [x] Three host entry points `hosts/<name>/default.nix` — minimal placeholders
      (`system.stateVersion`, hostname) that build without hardware configs
      (use a stub `fileSystems` / `boot.loader` so `toplevel` evaluates)
- [x] `formatter` output: `nixfmt-rfc-style`
- [x] `devShells.default` with `nil`, `statix`, `deadnix`, `nixfmt-rfc-style`
- [ ] Commit `flake.lock` (requires local `nix flake lock` — deferred to first local run)
- [x] Document the layout conventions in the top-level README (update Status section)

## Testing

- [ ] `nix flake check` passes
- [ ] `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`
      succeeds for all three hosts
- [ ] `nix fmt -- --check .` clean; `statix check` and `deadnix` report nothing
- [ ] `nix develop` enters the devShell with all tools on PATH

## Open questions

- [x] nixpkgs channel: **`nixos-unstable`** — needed for Hyprland and chaotic-nyx
      (ADR 003). Recorded in DECISIONS.md.
- [x] Hyprland source: **deferred to Ticket 04** — no Hyprland input added yet;
      can add the Hyprland flake input there if the nixpkgs package lags.
- [x] Username: **`maudi`** — same on all three machines.

## Ask when starting

- Nothing flagged from the old config for this ticket.
