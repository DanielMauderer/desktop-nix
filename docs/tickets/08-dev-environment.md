# 08 — Dev environment (replaces toolbox)

- **Status:** done
- **Depends on:** 03, 06
- **Machines:** desktop, work-laptop (light profile: private-laptop)

## Goal

Replace the Silverblue `dev-tools` toolbox container with nix-native
tooling: language toolchains, cargo extras, containers (podman), and the
Claude Code configuration. Document the workflow change ("toolbox enter" →
devshells/direnv).

## Sub-tasks

- [x] **Strategy decision:** thin set of global `home.packages` for daily
      drivers (rust, node?) + per-project `devShells` with direnv/nix-direnv
      for everything else (recommended) — record in DECISIONS.md
      (`modules/home/dev/`, DECISIONS 027)
- [x] Rust: toolchain source (nixpkgs rustc/cargo vs fenix/rust-overlay for
      channel control) + `cargo-nextest`, `bacon` — **nixpkgs** chosen; `cw`
      (bacon) and `ct` (cargo-nextest) aliases now resolve
- [x] Other toolchains used by the nvim setup: go, node (replaces nvm), python
      (+ uv for venvs), C toolchain — owned by `modules/home/dev`, removed from
      the neovim module (no duplication)
- [x] direnv + nix-direnv via HM; devshell templates (`templates/{rust,go,node,
      python}` + `devShells.<lang>`) for rust/go/node/python
- [x] Containers: `virtualisation.podman` (+ dockerCompat for the
      `docker`→podman alias), `podman-compose` (`modules/nixos/dev/`)
- [x] Claude Code config from MyLinux `claude/`: settings.json, statusline.sh,
      commands/, hooks/ — linked as **individual files** into `~/.claude`
      (`modules/home/dev/claude.nix`); rustfmt/clippy hooks find their tools on
      PATH from the dev module
- [x] Update fish aliases from Ticket 06: `tb`/`tbr` already removed (Ticket 06);
      `docker`→podman now backed by a real podman
- [x] Document the new workflow in `docs/dev-environment.md` (how to start a
      project devshell)

## Testing

- [x] Baseline: flake check, linters, all host builds, CI green
- [x] Each devshell template enters and compiles a hello-world
      (`dev-rust-check`/`dev-go-check`/`dev-node-check`/`dev-python-check` flake
      checks — offline)
- [x] `nixosTest` (`test-podman`): podman runs a container (store-loaded image,
      no network), `docker` compat works, podman-compose present
- [x] bacon launches; `cargo nextest` runs in a sample project (dev-rust-check)
- [x] Claude Code: `~/.claude/settings.json` symlink correct, hook script
      executes (rustfmt found), `settings.local.json` stays untouched/writable

## Open questions

- [ ] Rust via nixpkgs vs fenix/rust-overlay (do you need nightly/specific
      channels)? rustup is an anti-pattern on NixOS.
- [ ] Which languages deserve global installs vs devshell-only? (Work projects
      may have their own flakes/direnv already?)
- [ ] Node: single global LTS (for nvim plugins/LSPs) + per-project pinning
      via devshell?

## Ask when starting

- The toolbox pattern dies entirely — confirm no workflow depends on a
  mutable container (e.g. ad-hoc `dnf install` experiments). `distrobox` could
  be provided as an escape hatch if wanted.
- `setup.sh` installed eza/matugen into the toolbox but they're needed by the
  *host* session (fish alias, theming) — on NixOS they're regular packages;
  matugen ownership moves to Ticket 05, eza to Ticket 06. Confirm.
