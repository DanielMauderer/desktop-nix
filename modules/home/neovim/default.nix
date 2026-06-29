# Neovim home-manager module — Ticket 07, Machines: all.
#
# Strategy (DECISIONS 024): keep the existing lazy.nvim config as-is, linked via
# home.activation so edits inside ~/desktop-nix/nvim/ take effect without a rebuild.
# home.activation runs at switch time (not build time), so the symlink is safe in
# the Nix sandbox. Mason is kept as a UI layer only — all LSP servers, formatters,
# and debuggers come from Nix packages below (dynamic-linking on NixOS breaks
# Mason-downloaded binaries). rust_analyzer is managed by rustaceanvim.
#
# The language toolchains/runtimes themselves (cargo/rustc/rustfmt, gcc/gnumake,
# nodejs) live in modules/home/dev (Ticket 08, DECISIONS 027) — that module owns
# them and the two always load together via modules/nixos/base/home.nix. This
# module keeps only editor-specific tooling.
{
  config,
  lib,
  options,
  pkgs,
  ...
}:
lib.mkMerge [
  {
    # Install neovim; vimAlias/viAlias provide `vi` and `vim` → nvim wrappers.
    # No extraConfig/plugins are declared here — the full config lives in nvim/.
    programs.neovim = {
      enable = true;
      vimAlias = true;
      viAlias = true;
      # CRITICAL for the symlink below: home-manager otherwise writes the generated
      # init.lua (provider settings + any theming target) to ~/.config/nvim/init.lua.
      # That turns ~/.config/nvim into a managed directory, so the `ln -sfn` in
      # home.activation.nvimConfig can't replace it and nests the link one level deep
      # (~/.config/nvim/nvim) — nvim then loads the generated init.lua instead of the
      # repo's lazy.nvim config (wrong theme, no plugins). sideloadInitLua loads the
      # provider settings via a wrapper `--cmd 'lua dofile(...)'` instead, leaving
      # ~/.config/nvim free for the symlink. (See stylix.targets.neovim below too.)
      sideloadInitLua = true;
      # Only the python3 provider is used (pynvim, below). Drop the Ruby/Node/Perl
      # providers that home-manager pulls in by default — nothing in the config
      # uses them, so they only bloat the closure and add :checkhealth warnings.
      withPython3 = true;
      withRuby = false;
      withNodeJs = false;
      withPerl = false;
      # pynvim host (:checkhealth python3) lives inside neovim's own python3
      # wrapper, NOT in home.packages — otherwise a `python3.withPackages` env
      # collides with the bare python3 the dev module (Ticket 08) puts on PATH.
      extraPython3Packages = ps: [ ps.pynvim ];
    };

    # Stylix themes neovim via mini.base16 (a blue base16 palette) by enabling
    # programs.neovim's generated init.lua. We manage the colorscheme ourselves
    # (ember, set in nvim/lua/plugins/init.lua), and that generated init.lua is what
    # would block the ~/.config/nvim symlink — so disable the target, like the
    # waybar/hyprland/kitty targets elsewhere.
    #
    # The guarded fragment at the bottom of this mkMerge sets the target only where
    # stylix exists (see note there).

    # Symlink the repo's nvim/ dir into ~/.config/nvim at activation time.
    # Using home.activation instead of xdg.configFile avoids the Nix build-sandbox
    # restriction: xdg.configFile recursively enumerates directory sources at build
    # time, which fails when the target (~/desktop-nix/nvim) is outside the store.
    home.activation.nvimConfig = {
      after = [ "writeBoundary" ];
      before = [ ];
      data = ''
        target="${config.xdg.configHome}/nvim"
        # `ln -sfn` descends into an existing *real* directory instead of replacing
        # it (it would create ~/.config/nvim/nvim). With sideloadInitLua = true
        # home-manager no longer creates that directory, but an earlier generation
        # may have left one behind — remove it first. Existing symlinks are replaced
        # in place by `ln -sfn`, so only real directories need clearing.
        if [ -d "$target" ] && [ ! -L "$target" ]; then
          rm -rf "$target"
        fi
        ln -sfn "${config.home.homeDirectory}/desktop-nix/nvim" "$target"
      '';
    };

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

      # Treesitter parser compilation (gcc/gnumake/nodejs), conform's rustfmt and
      # the PATH python3 all rely on the toolchains from modules/home/dev
      # (Ticket 08) — present in the same home profile. The pynvim host is wired via
      # programs.neovim.extraPython3Packages above (inside the nvim wrapper) to
      # avoid a python3 env PATH collision.

      # ── Clipboard ─────────────────────────────────────────────────────────────
      wl-clipboard # vim.o.clipboard = "unnamedplus" on Wayland
    ];
  }

  # Stylix target, guarded so it contributes nothing where stylix is absent.
  # This module loads on every host (Machines: all) but stylix is only imported by
  # the desktop module (modules/nixos/desktop/theming.nix). On headless hosts
  # (home-server) the option is undeclared, and *defining* a non-existent option —
  # even as `{}` — is an eval error, not a no-op. lib.optionalAttrs drops the whole
  # `stylix` key when the option isn't declared, so nothing is defined there.
  (lib.optionalAttrs (options ? stylix) {
    stylix.targets.neovim.enable = false;
  })
]
