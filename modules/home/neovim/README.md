# neovim

Neovim (home-manager) — imported on every host.

- `default.nix` — builds the three plugins not in nixpkgs (`ember`, `pretty_hover`,
  `tiny-code-action`) from flake inputs, imports the **nixvim** home module, and
  disables the stylix neovim target (nixvim owns the colorscheme).
- `settings.nix` — the actual `programs.nixvim` value: options, globals, keymaps,
  the `ember` colorscheme, treesitter (nixvim's main-branch module, grammars from
  Nix) and every other plugin (from nixpkgs `extraPlugins` + ported Lua in
  `extraConfigLua`). Split out as a plain function so it can be built standalone
  with `nixvim`'s `makeNixvimWithModule` for testing.

The whole editor config is **declarative** (DECISIONS 024, revised): no Lua files,
no runtime plugin git-clones — a `nixos-rebuild` builds it. LSP servers, formatters
and DAP adapters come from Nix (`extraPackages`); Mason is not used
(Mason-downloaded binaries break under NixOS dynamic linking). `rust_analyzer` is
managed by rustaceanvim; the language runtimes themselves come from
`modules/home/dev`.
