# 07 — Neovim

- **Status:** open
- **Depends on:** 06
- **Machines:** all

## Goal

The existing ~40-plugin lazy.nvim configuration working unchanged on NixOS,
with the external binaries it needs (LSP servers, formatters, debuggers,
treesitter compilers) provided by nix instead of Mason where they break.

## Sub-tasks

- [ ] **Decision:** keep the config as-is, linked via `xdg.configFile` /
      `mkOutOfStoreSymlink` to the repo checkout (recommended initially —
      config stays editable without rebuilds) vs nixvim rewrite (full
      declarative, big effort). Record in DECISIONS.md.
- [ ] Move the `nvim/` config dir from MyLinux into this repo
- [ ] Provide via `home.packages`: language servers (`lua_ls`, `gopls`,
      `clangd`, `html`/`cssls`/`jsonls` via vscode-langservers, `yamlls`,
      rust-analyzer for rustaceanvim), formatters (stylua, prettierd, isort,
      ruff, gofumpt, clang-format, jq, sqruff), debuggers (gdb,
      js-debug-adapter), build deps (gcc/make for treesitter, nodejs)
- [ ] Mason strategy: disable mason auto-install for native binaries (breaks
      on NixOS due to dynamic linking) — point lspconfig/conform at
      nix-provided binaries; decide whether Mason stays for anything
- [ ] Verify lazy.nvim writes (lazy-lock.json, plugin downloads in
      `~/.local/share/nvim`) still work — they should, they're outside the store
- [ ] Wire the Claude Code PostToolUse rustfmt hook context (claude/ config)
      — actual claude config port happens in Ticket 08

## Testing

- [ ] Baseline: flake check, linters, all host builds, CI green
- [ ] `nixosTest` or HM build-VM check: `nvim --headless "+Lazy! sync" +qa`
      exits 0 (all plugins install/build, incl. fff.nvim's Rust build and
      treesitter parsers compiling against nix gcc)
- [ ] Headless LSP smoke test: open a fixture file per language (rust, go, c,
      ts, py, lua) and assert the LSP client attaches
- [ ] `:checkhealth` has no errors for providers used (python3-neovim parity)
- [ ] Manual: debugging session starts (gdb DAP), formatter runs (`<leader>fo`)

## Open questions

- [ ] Keep-as-is vs nixvim — and if keep-as-is: `mkOutOfStoreSymlink`
      (editable, but ties activation to the repo's checkout path) vs copying
      into the store (immutable, edit = rebuild)?
- [ ] Mason fully disabled or kept for pure-script tools?
- [ ] lazy-lock.json: commit it here for plugin reproducibility?

## Ask when starting

- The CLAUDE.md-documented plugin list is the source of truth; verify against
  `nvim/lua/plugins/` for drift before porting.
- Mason currently auto-installs stylua/prettierd/isort/ruff/gofumpt/
  clang-format — these all exist in nixpkgs; confirm switching them over in
  one go.
