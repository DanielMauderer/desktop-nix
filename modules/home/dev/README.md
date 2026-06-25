# dev

Per-user dev environment — wired in by `base` on every workstation. Replaces the
old Silverblue `dev-tools` toolbox with nix-native tooling. This module owns the
**language toolchains**; the `neovim` module keeps only editor tooling (LSP,
formatters, DAP). They always load together.

| File         | Configures                                                        |
|--------------|------------------------------------------------------------------|
| `default.nix`| Global toolchains: Rust (`cargo rustc rustfmt clippy` + `cargo-nextest`, `bacon`), Go, Node (LTS), Python (`python3` + `uv`), C (`gcc gnumake`), git tooling (`git-spice`, `gh`), `claude-code`; plus direnv + nix-direnv. |
| `claude.nix` | Links the personal Claude config (`claude/`) into `~/.claude`.    |

## Where tools come from

- **Global daily drivers** — always on PATH (this module).
- **Editor tooling** (LSP/formatters/DAP) — `modules/home/neovim`.
- **Containers** — Podman (`modules/nixos/dev`), `docker` shim + `podman-compose`.
- **Per-project, pinned** — Nix devShells via direnv.

## Project devshells (replaces `toolbox enter`)

```fish
cd my-project
nix flake init -t ~/desktop-nix#rust   # or #go / #node / #python
direnv allow                            # loads the toolchain on cd, every time
```
Or without scaffolding: `nix develop ~/desktop-nix#rust`. To add a tool
*everywhere*, edit the module and rebuild; for a one-off use `nix shell nixpkgs#<pkg>`.

## Claude Code

`claude/` is linked as individual files into `~/.claude` (`settings.json`,
`statusline.sh`, `CLAUDE.md`, `hooks/`, `commands/`); the rest of `~/.claude` stays
writable machine-local state. The rustfmt PostToolUse hook and the clippy Stop
hook use the Rust toolchain on PATH. Edit the tracked files and rebuild to change it.
