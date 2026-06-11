# 08 — Dev environment (replaces toolbox)

- **Status:** open
- **Depends on:** 03, 06
- **Machines:** desktop, work-laptop (light profile: private-laptop)

## Goal

Replace the Silverblue `dev-tools` toolbox container with nix-native
tooling: language toolchains, cargo extras, containers (podman), and the
Claude Code configuration. Document the workflow change ("toolbox enter" →
devshells/direnv).

## Sub-tasks

- [ ] **Strategy decision:** thin set of global `home.packages` for daily
      drivers (rust, node?) + per-project `devShells` with direnv/nix-direnv
      for everything else (recommended) — record in DECISIONS.md
- [ ] Rust: toolchain source (nixpkgs rustc/cargo vs fenix/rust-overlay for
      channel control) + `cargo-nextest`, `bacon` (replaces toolbox cargo
      installs; `cw` alias and `<leader>rb` integration keep working)
- [ ] Other toolchains used by the nvim setup: go, node (replaces nvm), python
      (+ venv-selector workflow), C toolchain
- [ ] direnv + nix-direnv via HM; devshell templates (`templates/` or
      `devShells.<lang>`) for rust/go/node/python
- [ ] Containers: `virtualisation.podman` (+ dockerCompat for the
      `docker`→podman alias), `podman-compose`
- [ ] Claude Code config from MyLinux `claude/`: settings.json, statusline.sh,
      commands/, hooks/ — linked as **individual files** into `~/.claude`
      (never the whole dir — it holds live state); rustfmt PostToolUse hook
      must find rustfmt on PATH outside toolbox now
- [ ] Update fish aliases from Ticket 06: `tb`/`tbr` removed/replaced,
      `docker`→podman verified
- [ ] Document the new workflow in `docs/` (how to start a project devshell)

## Testing

- [ ] Baseline: flake check, linters, all host builds, CI green
- [ ] Each devshell template enters and compiles a hello-world
      (`cargo nextest run`, `go test`, `node -e`, `python -c`) — wire as
      flake `checks` where cheap
- [ ] `nixosTest`: podman runs a container (`podman run --rm alpine true`),
      `docker` alias/compat works, podman-compose up on a fixture compose file
- [ ] bacon launches; `cargo nextest` runs in a sample project
- [ ] Claude Code: `~/.claude/settings.json` symlink correct, hook script
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
