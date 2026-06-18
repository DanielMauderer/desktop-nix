# neovim

Neovim (home-manager) — imported on every host.

- `default.nix` — installs Neovim (`vi`/`vim` aliases) and the LSP servers,
  formatters and DAP adapters as **Nix packages** (Mason is a UI layer only —
  Mason-downloaded binaries break under NixOS dynamic linking). Only the python3
  provider is kept (pynvim); Ruby/Node/Perl providers are dropped.

The full lazy.nvim config lives in `nvim/` (repo root) and is **symlinked** via
`home.activation`, so edits there take effect without a rebuild. `rust_analyzer`
is managed by rustaceanvim; the language runtimes themselves come from
`modules/home/dev`.
