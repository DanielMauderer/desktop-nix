# dev

Per-user dev environment — wired in by `base` on every workstation. It owns
`gh`, `claude-code`, direnv, and the personal Claude Code config.

It deliberately owns **no language toolchain**. The `neovim` module keeps editor
tooling (LSP, formatters, DAP) on Neovim's own wrapper PATH; everything else
comes from the project you are standing in.

| File         | Configures                                                      |
|--------------|-----------------------------------------------------------------|
| `default.nix`| `gh`, `claude-code`, and direnv + nix-direnv.                    |
| `claude.nix` | Links the personal Claude config (`claude/`) into `~/.claude`.   |

## Where tools come from

- **Per-project, pinned** — Nix devShells via direnv. The only source of a
  compiler, interpreter or package manager.
- **Editor tooling** (LSP/formatters/DAP) — `modules/home/neovim`, on nvim's
  wrapper PATH only.
- **Containers** — Podman (`modules/nixos/dev`), `docker` shim + `podman-compose`.

## No global toolchains

There is no global `cargo`, `go`, `node`, `python3` or `cc`. A global copy
shadows the version a project pins, and PATH order decides which one wins with
nothing at the prompt to say so — debugging that is why they were removed.

Give a project its own `flake.nix` with the toolchain in `mkShell`, plus an
`.envrc` containing `use flake`, then `direnv allow`; direnv loads it on `cd`,
every time. For a genuine one-off, `nix shell nixpkgs#<pkg>`.

## Claude Code

`claude/` is linked as individual files into `~/.claude` (`settings.json`,
`CLAUDE.md`); the rest of `~/.claude` stays writable machine-local state. Edit
the tracked files and rebuild to change it.

Nothing here registers hooks: a hook lives in the global config but fires in
every project, so a Rust formatter runs in an Angular repo. Anything
language-specific belongs in that repo's own `.claude/`.
