# 10 — Flatpak strategy

- **Status:** done
- **Depends on:** 03
- **Machines:** all

## Goal

A per-app decision for the four flatpaks from maudiblue (Zen Browser,
Spotify, Flatseal, Warehouse): nixpkgs package, community flake, or keep as
flatpak (then managed declaratively via nix-flatpak). On Silverblue flatpak
was the *primary* app mechanism; on NixOS it's optional — the likely outcome
is "mostly nixpkgs, flatpak only if something needs it".

## Sub-tasks

- [x] Per-app decision matrix (record in DECISIONS.md):
  - [x] **Spotify** — `pkgs.spotify` nixpkgs unfree (DECISIONS 029)
  - [x] **Zen Browser** — `0xc000022070/zen-browser-flake` twilight (DECISIONS 030)
  - [x] **Flatseal / Warehouse** — dropped; no flatpak stays (DECISIONS 031/032)
- [x] If any flatpak remains: N/A — no flatpak on NixOS (DECISIONS 031)
- [x] If none remain: flatpak dropped — `services.flatpak` stays off (default)
- [x] `nixpkgs.config.allowUnfreePredicate` allow-list in `modules/nixos/apps.nix`;
      steam entries added in Ticket 11
- [x] Other GUI apps: thunar (Ticket 04), mpv, imv — all nixpkgs (DECISIONS 033)

## Testing

- [x] Baseline: flake check, linters, all host builds, CI green
- [x] nix-flatpak: N/A — no flatpak; allowUnfreePredicate + package presence
      asserted in `baseAssertions` (flake.nix)
- [x] Unfree allow-list is exact: `allowUnfreePredicate` in `modules/nixos/apps.nix`;
      build fails on any unlisted unfree (negative test: omitting spotify from
      the list would fail the spotify build)
- [ ] Manual on hardware: Spotify launches + audio (PipeWire), Zen profile
      migration (Ticket 13 runbook)

## Open questions

- [x] Keep flatpak at all? No — all apps covered by nixpkgs / community flake
      (DECISIONS 031).
- [x] Zen Browser update cadence: community flake `twilight` channel chosen
      for reproducibility (DECISIONS 030).
- [ ] Browser profiles / Spotify cache migration: runbook material for Ticket 13.

## Ask when starting

- maudiblue configured *both* a user and a system Flathub remote with apps at
  system scope — on NixOS, if flatpak stays, pick one scope (user recommended)
  and confirm.
  **Resolved:** no flatpak on NixOS (DECISIONS 031); scope question is moot.
