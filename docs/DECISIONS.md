# Architecture Decisions

ADR-lite log. One entry per decision: context, decision, consequences.
Add an entry whenever a ticket resolves one of its "Open questions".

---

## 001 — Plain flake, no flake-parts (2026-06-11)

**Context:** The repo manages 3 hosts with home-manager. flake-parts adds a
module system for flake outputs, which pays off with many per-system outputs
and complex output wiring.

**Decision:** Use a plain `flake.nix` plus a small `lib/mkHost.nix` helper.

**Consequences:** Less abstraction to learn while simultaneously learning
NixOS. Revisit if `checks`/`devShells` boilerplate grows — migrating to
flake-parts later is mechanical.

---

## 002 — home-manager as a NixOS module, not standalone (2026-06-11)

**Context:** home-manager can run standalone (`home-manager switch`) or as a
NixOS module (one `nixos-rebuild switch` for system + home).

**Decision:** Use home-manager as a NixOS module.

**Consequences:** Host and home configuration stay atomic — no version skew
between system and home generations; a single rollback covers both. Trade-off:
home changes require a system rebuild (acceptable: single-user machines).

---

## 003 — CachyOS kernel via chaotic-cx/nyx (2026-06-11)

**Context:** The desktop host wants the CachyOS kernel for gaming performance.
On NixOS this is packaged by the [chaotic-cx/nyx](https://github.com/chaotic-cx/nyx)
flake (`linuxPackages_cachyos`, `scx` schedulers) with a binary cache.

**Decision:** Add chaotic-nyx as a flake input, enabled only on the `desktop`
host. Use its binary cache to avoid local kernel compiles (details in Ticket 11).

**Consequences:** Desktop kernel updates follow chaotic-nyx's cadence; CI must
trust the chaotic cache or skip the kernel build.

---

## 005 — nixpkgs channel: nixos-unstable (2026-06-11)

**Context:** Ticket 01 required choosing between `nixos-unstable` and a stable
release for the nixpkgs input.

**Decision:** Use `nixos-unstable`. Hyprland and chaotic-nyx move fast and
both track unstable; using a stable branch would require constant back-porting
or overlay pinning.

**Consequences:** System is on rolling nixpkgs; occasional evaluation breakage
is possible. Mitigated by CI catching broken builds before they reach hardware.

---

## 006 — Hyprland from the Hyprland flake, not nixpkgs (2026-06-11)

**Context:** Ticket 04 (Hyprland desktop stack) needs Hyprland. It is also
packaged in nixpkgs, but the upstream flake ships newer commits and the
Hyprland project recommends it.

**Decision:** Add `github:hyprwm/Hyprland` as a flake input, following
nixpkgs. The input was added in Ticket 01 so the lock file is established
early; the module wiring happens in Ticket 04.

**Consequences:** Hyprland version follows the upstream flake, independent of
the nixpkgs Hyprland package. Adds one extra flake input to track.

---

## 007 — Username: `maudi` on all machines (2026-06-11)

**Context:** All three machines are personal, single-user.

**Decision:** The primary user account is `maudi` on all three machines.

**Consequences:** Modules can use a shared username constant rather than
per-host overrides. If this ever changes, one value to update.

---

## 008 — CI binary cache: magic-nix-cache (2026-06-11)

**Context:** Ticket 02 required choosing a binary cache strategy for CI to
avoid rebuilding the world on every run.

**Decision:** Use `DeterminateSystems/magic-nix-cache-action`. Zero-config,
integrates with GitHub Actions cache automatically, no account or token needed.

**Consequences:** Cache is scoped to the GitHub Actions cache of the repo
(7 GB limit, evicted after 7 days of inactivity). Works out-of-the-box on
push/PR. If cache requirements outgrow the limit, revisit cachix.

---

## 009 — Pre-commit hooks: CI only (2026-06-11)

**Context:** Ticket 02 considered whether to enforce lint/format checks via
git-hooks.nix locally in addition to CI.

**Decision:** CI only. No local pre-commit hook setup required.

**Consequences:** Developers can commit un-linted code locally; CI catches
it and the PR stays red until fixed. Reduces friction for work-in-progress
commits. The `devShell` already ships `statix`, `deadnix`, and `nixfmt-rfc-style`
so manual checks are one command away.

---

## 010 — nixosTest coverage bar: assert multi-user.target (2026-06-11)

**Context:** Ticket 02 required deciding how far to take `nixosTest` for
graphical stacks (Hyprland can start headless in a VM).

**Decision:** The baseline nixosTest asserts `multi-user.target` reached.
Later tickets extend this pattern (e.g. assert Hyprland session unit active,
libvirtd active) by copying the template in `checks.x86_64-linux`.

**Consequences:** Boot-level regression is caught automatically from Ticket 02
onward. Graphical assertions are left to the relevant ticket (04 for Hyprland,
09 for libvirt) rather than being forced into the baseline.

---

## 004 — Migration order: private-laptop → work-laptop → desktop (2026-06-11)

**Context:** Three machines with different risk profiles.

**Decision:** Pilot on the private laptop (lowest risk), apply lessons, then
the work laptop, then the gaming desktop.

**Consequences:** Gaming/CachyOS stack (Ticket 11) is validated last on real
hardware, even though it can be developed and CI-built earlier.
