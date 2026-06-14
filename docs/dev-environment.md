# Dev environment workflow

How development tooling works on these machines after the Silverblue → NixOS
migration (Ticket 08, DECISIONS 027). The old `dev-tools` **toolbox** is gone —
there is no mutable container to `toolbox enter` anymore.

## Where tools come from

- **Global daily-driver toolchains** (always on PATH) — `modules/home/dev/`:
  Rust (`cargo rustc rustfmt clippy` + `cargo-nextest`, `bacon`), Go, Node (LTS),
  Python (`python3` + `uv`), a C toolchain (`gcc gnumake`), and git tooling
  (`git-spice`, `gh`).
- **Editor tooling** (LSP servers, formatters, DAP) — `modules/home/neovim/`.
- **Containers** — podman (`modules/nixos/dev/`), with a `docker` compat shim and
  `podman-compose`.
- **Per-project, pinned toolchains** — Nix devShells + direnv (below).

To add a tool *everywhere*, edit the relevant module and `update`
(`sudo nixos-rebuild switch --flake ~/desktop-nix`). For a one-off, use
`nix shell nixpkgs#<pkg>` — no need to pollute the system.

## Starting a project devshell (replaces `toolbox enter`)

Scaffold a shell for a new project from a template:

```fish
cd my-project
nix flake init -t ~/desktop-nix#rust   # or #go / #node / #python
direnv allow                            # loads the toolchain on cd, every time
```

`nix flake init -t` drops a `flake.nix` (the devShell) and a `.envrc`
(`use flake`). `direnv allow` is a one-time trust step; afterwards the toolchain
is active whenever you `cd` into the directory and gone when you leave. Edit the
generated `flake.nix` to pin versions or add project-specific packages.

To enter a shell without scaffolding files:

```fish
nix develop ~/desktop-nix#rust
```

## Containers

Podman is the runtime. The fish `docker` alias and the `dockerCompat` shim both
point at podman, so existing `docker …` / `docker-compose …` muscle memory works;
`podman-compose` is available for compose files.

```fish
docker run --rm alpine true     # → podman
podman-compose up
```

## Claude Code

The personal Claude config lives in `modules/home/dev/claude/` and is linked as
individual files into `~/.claude` (`settings.json`, `statusline.sh`, `CLAUDE.md`,
`hooks/`, `commands/`). `~/.claude/settings.local.json` and the rest of
`~/.claude` stay writable, machine-local state. The rustfmt PostToolUse hook and
the pedantic-clippy Stop hook use the Rust toolchain on PATH. Edit the tracked
files in the repo and `update` to change the config.
