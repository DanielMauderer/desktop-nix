# 01 — Repo bootstrap: flake skeleton

- **Status:** open
- **Depends on:** —
- **Machines:** all

## Goal

A minimal flake that evaluates and builds three empty-but-valid
`nixosConfigurations` (`private-laptop`, `work-laptop`, `desktop`). This is the
foundation every other ticket builds on — no real configuration yet, just the
structure, formatter, and dev tooling.

## Sub-tasks

- [ ] `flake.nix` with inputs: `nixpkgs`, `home-manager` (channel decision below)
- [ ] `lib/mkHost.nix` helper: host name + module list → `nixosConfiguration`,
      wires home-manager as a NixOS module (DECISIONS.md #002) and shared `specialArgs`
- [ ] Three host entry points `hosts/<name>/default.nix` — minimal placeholders
      (`system.stateVersion`, hostname) that build without hardware configs
      (use a stub `fileSystems` / `boot.loader` so `toplevel` evaluates)
- [ ] `formatter` output: `nixfmt-rfc-style`
- [ ] `devShells.default` with `nil`, `statix`, `deadnix`, `nixfmt-rfc-style`
- [ ] Commit `flake.lock`
- [ ] Document the layout conventions in the top-level README (update Status section)

## Testing

- [ ] `nix flake check` passes
- [ ] `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`
      succeeds for all three hosts
- [ ] `nix fmt -- --check .` clean; `statix check` and `deadnix` report nothing
- [ ] `nix develop` enters the devShell with all tools on PATH

## Open questions

- [ ] nixpkgs channel: `nixos-unstable` (recommended — Hyprland and chaotic-nyx
      move fast) vs a stable release (25.05) with selective unstable overlays?
- [ ] Hyprland from nixpkgs or from the Hyprland flake (newer, but more moving
      parts)? Can be deferred to Ticket 04 but affects inputs.
- [ ] Username in the config: same user name on all three machines?

## Ask when starting

- Nothing flagged from the old config for this ticket.
