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

## 004 — Migration order: private-laptop → work-laptop → desktop (2026-06-11)

**Context:** Three machines with different risk profiles.

**Decision:** Pilot on the private laptop (lowest risk), apply lessons, then
the work laptop, then the gaming desktop.

**Consequences:** Gaming/CachyOS stack (Ticket 11) is validated last on real
hardware, even though it can be developed and CI-built earlier.
