# Pure-Nix unit tests for modules/home/neovim/settings.nix.
#
# settings.nix is a plain function (see its own header comment) so it is
# tested directly here without going through nixvim's module system or
# building any plugin. `pkgs` must be a real nixpkgs so the
# `with pkgs.vimPlugins; [...]` list and the `extraPackages` package
# references resolve; the three plugins that are normally built from flake
# inputs (ember/pretty-hover/tiny-code-action) are passed in as plain marker
# attrsets instead of real derivations, since settings.nix only ever puts
# them in a list. Wired into flake.nix as the `unit-nvim-settings-check`
# check via `mkUnitCheck`.
{ lib, pkgs }:
let
  mockEmber = {
    pname = "ember-mock";
  };
  mockPrettyHover = {
    pname = "pretty-hover-mock";
  };
  mockTinyCodeAction = {
    pname = "tiny-code-action-mock";
  };

  cfg = import ./settings.nix {
    inherit pkgs;
    ember = mockEmber;
    pretty-hover = mockPrettyHover;
    tiny-code-action = mockTinyCodeAction;
  };
in
[
  {
    name = "nixvim is enabled";
    assertion = cfg.enable == true;
  }
  {
    name = "vi/vim aliases are on";
    assertion = cfg.viAlias == true && cfg.vimAlias == true;
  }
  {
    name = "only the python3 provider is kept (Ruby/Node/Perl dropped)";
    assertion =
      cfg.withPython3 == true && cfg.withRuby == false && cfg.withNodeJs == false && cfg.withPerl == false;
  }
  {
    name = "ember is the colorscheme";
    assertion = cfg.colorscheme == "ember";
  }
  {
    name = "core opts match the ported lazy.nvim config";
    assertion =
      cfg.opts.tabstop == 4
      && cfg.opts.shiftwidth == 4
      && cfg.opts.expandtab == true
      && cfg.opts.mouse == "a"
      && cfg.opts.clipboard == "unnamedplus"
      && cfg.opts.termguicolors == true
      && cfg.opts.relativenumber == true;
  }
  {
    name = "leader and local-leader are space";
    assertion = cfg.globals.mapleader == " " && cfg.globals.maplocalleader == " ";
  }
  {
    name = "netrw is disabled in favour of the file-explorer plugins";
    assertion = cfg.globals.loaded_netrw == 1 && cfg.globals.loaded_netrwPlugin == 1;
  }
  {
    name = "exactly the five base keymaps from init.lua are declared";
    assertion = builtins.length cfg.keymaps == 5;
  }
  {
    name = "<leader>e opens the floating diagnostic in normal mode";
    assertion = builtins.any (k: k.key == "<leader>e" && k.mode == "n") cfg.keymaps;
  }
  {
    name = "<leader>q sends diagnostics to the location list";
    assertion = builtins.any (k: k.key == "<leader>q") cfg.keymaps;
  }
  {
    name = "treesitter highlighting and indent are enabled";
    assertion =
      cfg.plugins.treesitter.enable == true
      && cfg.plugins.treesitter.highlight.enable == true
      && cfg.plugins.treesitter.indent.enable == true;
  }
  {
    name = "the three unpackaged plugins passed in are threaded into extraPlugins";
    assertion =
      builtins.elem mockEmber cfg.extraPlugins
      && builtins.elem mockPrettyHover cfg.extraPlugins
      && builtins.elem mockTinyCodeAction cfg.extraPlugins;
  }
  {
    name = "claudecode-nvim (from nixpkgs) is included";
    assertion = builtins.elem pkgs.vimPlugins.claudecode-nvim cfg.extraPlugins;
  }
  {
    name = "a representative set of nixpkgs plugins is included";
    assertion = lib.all (p: builtins.elem p cfg.extraPlugins) [
      pkgs.vimPlugins.blink-cmp
      pkgs.vimPlugins.neo-tree-nvim
      pkgs.vimPlugins.gitsigns-nvim
      pkgs.vimPlugins.rustaceanvim
    ];
  }
  {
    name = "LSP servers/formatters/DAP adapters land on extraPackages";
    assertion = lib.all (p: builtins.elem p cfg.extraPackages) [
      pkgs.rust-analyzer
      pkgs.stylua
      pkgs.gopls
      pkgs.gdb
    ];
  }
  {
    name = "extraConfigLua wires up claudecode, tiny-code-action and the LSP manager";
    assertion = lib.all (s: lib.hasInfix s cfg.extraConfigLua) [
      "require(\"claudecode\").setup"
      "require(\"tiny-code-action\").setup"
      "LspManager.open_lsp_picker"
    ];
  }
  {
    name = "the injected plugins are not hardcoded (swapping them changes extraPlugins)";
    assertion =
      let
        alt = import ./settings.nix {
          inherit pkgs;
          ember = {
            pname = "different-mock";
          };
          pretty-hover = mockPrettyHover;
          tiny-code-action = mockTinyCodeAction;
        };
      in
      !(builtins.elem mockEmber alt.extraPlugins);
  }
]