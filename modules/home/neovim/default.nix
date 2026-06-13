# Neovim home-manager module — Ticket 07, Machines: all.
#
# Strategy (DECISIONS 024): keep the existing lazy.nvim config as-is, linked via
# mkOutOfStoreSymlink so edits inside ~/desktop-nix/nvim/ take effect without
# a rebuild. Mason is kept as a UI layer only — all LSP servers, formatters, and
# debuggers come from Nix packages below (dynamic-linking on NixOS breaks
# Mason-downloaded binaries). rust_analyzer is managed by rustaceanvim.
{
  config,
  pkgs,
  ...
}:
{
  # Install neovim; vimAlias/viAlias provide `vi` and `vim` → nvim wrappers.
  # No extraConfig/plugins are declared here — the full config lives in nvim/.
  programs.neovim = {
    enable = true;
    vimAlias = true;
    viAlias = true;
  };

  # Symlink the repo's nvim/ dir into ~/.config/nvim.
  # mkOutOfStoreSymlink means changes to lua/plugins/*.lua are instant — no
  # nixos-rebuild needed. The path matches the FLAKE_DIR convention (DECISIONS 022).
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/desktop-nix/nvim";

  home.packages = with pkgs; [
    # ── LSP servers ───────────────────────────────────────────────────────────
    lua-language-server # lua_ls
    gopls # go
    clang-tools # clangd + clang-format
    vscode-langservers-extracted # html / cssls / jsonls
    yaml-language-server # yamlls
    rust-analyzer # for rustaceanvim (excludes itself from lspconfig)

    # ── Formatters ────────────────────────────────────────────────────────────
    stylua # lua
    prettierd # js / ts / json / yaml / ...
    python3Packages.isort # python import sorter
    ruff # python linter + formatter
    gofumpt # go
    # clang-format is part of clang-tools above
    jq # json
    sqruff # sql (conform <leader>fs visual selection)

    # ── Debuggers / DAP adapters ──────────────────────────────────────────────
    gdb # C / C++ / Rust via gdb DAP
    vscode-js-debug # js-debug-adapter for TypeScript / JavaScript

    # ── Treesitter build deps ─────────────────────────────────────────────────
    # nvim-treesitter compiles native parsers; fff.nvim does `cargo build --release`.
    gcc
    gnumake
    nodejs # treesitter JS/TS parsers + js-debug runtime

    # ── Rust toolchain ────────────────────────────────────────────────────────
    cargo # fff.nvim build step + general Rust dev
    rustc
    rustfmt # conform.nvim rust formatter

    # ── Python neovim host ────────────────────────────────────────────────────
    (python3.withPackages (ps: [ ps.pynvim ])) # :checkhealth python3

    # ── Clipboard ─────────────────────────────────────────────────────────────
    wl-clipboard # vim.o.clipboard = "unnamedplus" on Wayland
  ];
}
