# 10 — Flatpak strategy

- **Status:** open
- **Depends on:** 03
- **Machines:** all

## Goal

A per-app decision for the four flatpaks from maudiblue (Zen Browser,
Spotify, Flatseal, Warehouse): nixpkgs package, community flake, or keep as
flatpak (then managed declaratively via nix-flatpak). On Silverblue flatpak
was the *primary* app mechanism; on NixOS it's optional — the likely outcome
is "mostly nixpkgs, flatpak only if something needs it".

## Sub-tasks

- [ ] Per-app decision matrix (record in DECISIONS.md):
  - [ ] **Spotify** — nixpkgs `spotify` (unfree) vs flatpak
  - [ ] **Zen Browser** — community flake (`0xc000022070/zen-browser-flake`)
        vs flatpak vs switch to nixpkgs firefox
  - [ ] **Flatseal / Warehouse** — only needed if any flatpak remains
- [ ] If any flatpak remains: `services.flatpak.enable` + nix-flatpak for
      declarative app lists + Flathub remote; user vs system scope
- [ ] If none remain: explicitly drop flatpak support (smaller system)
- [ ] `nixpkgs.config.allowUnfreePredicate` allow-list (spotify, steam later
      in Ticket 11) — central place, documented
- [ ] Other GUI apps used but not in the flatpak list (check on the live
      systems before deciding: file manager, image viewer, video player?) —
      add to the matrix

## Testing

- [ ] Baseline: flake check, linters, all host builds, CI green
- [ ] If nix-flatpak: `nixosTest`/manual — activation installs the declared
      apps idempotently (second switch: no re-install), Flathub remote
      configured
- [ ] Unfree allow-list is exact (build fails on an undeclared unfree package
      — negative test)
- [ ] Manual on hardware: each app launches, audio in Spotify works (pipewire),
      Zen profile migration done

## Open questions

- [ ] Keep flatpak at all? (Recommendation: only if Zen-as-flatpak wins, since
      sandboxed browser + Flatseal is a legit combo.)
- [ ] Zen Browser update cadence: community flake tracks releases fast but
      adds an input; flatpak auto-updates out of band (less declarative).
- [ ] Where do browser profiles / Spotify cache migrate from the old machines?
      (Runbook material for Ticket 13.)

## Ask when starting

- maudiblue configured *both* a user and a system Flathub remote with apps at
  system scope — on NixOS, if flatpak stays, pick one scope (user recommended)
  and confirm.
