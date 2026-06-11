# Claude Code — agent guidance for this repo

## Before picking the next task

**Always check `docs/tickets/README.md` first.** The Status column is the
single source of truth for what is done vs open. Do NOT rely on directory
listings or assumptions — previous agents have already implemented several
tickets.

Steps before starting any work:

1. Read `docs/tickets/README.md` → find the first ticket whose Status is
   `open` and whose `Depends on` tickets are all `done`.
2. Read the individual ticket file (`docs/tickets/NN-*.md`) for the full
   sub-task list, testing checklist, and open questions.
3. Check `git log --oneline origin/main` to confirm nothing was merged that
   the index hasn't caught up to yet.

## When finishing a ticket

Update **both** of these before opening a PR — missing either one will cause
the next agent to repeat your work:

1. `docs/tickets/NN-<slug>.md` — change `Status: open` → `Status: done`
2. `docs/tickets/README.md` — change the Status cell in the index table from
   `open` to `done`

## Repository layout

```
docs/tickets/README.md   ← ticket index (Status column = ground truth)
docs/tickets/NN-*.md     ← individual ticket files
docs/DECISIONS.md        ← ADR log; add an entry for every open question resolved
flake.nix                ← flake inputs and outputs
lib/mkHost.nix           ← nixosSystem factory (hostname, modules, withChaotic)
hosts/<name>/default.nix ← per-host stub configs
modules/                 ← reusable NixOS / home-manager modules (populated from Ticket 03 onward)
```

## Key architecture decisions (summary)

See `docs/DECISIONS.md` for the full log. Short version:

- **nixpkgs**: `nixos-unstable`
- **home-manager**: as a NixOS module (one `nixos-rebuild switch` for both)
- **Username**: `maudi` on all three machines
- **Hyprland**: from the upstream Hyprland flake (input already in `flake.nix`)
- **CachyOS kernel**: desktop only, via `chaotic-nyx` (`withChaotic = true` in `flake.nix`)
- **No flake-parts**: plain `flake.nix` + `lib/mkHost.nix`
