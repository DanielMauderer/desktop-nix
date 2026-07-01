# Neovim home-manager module — Machines: all.
#
# Strategy (DECISIONS 024, revised): the editor is configured declaratively with
# **nixvim** (programs.nixvim). The old lazy.nvim tree under nvim/ is gone — there
# are no Lua files and no runtime git-clones; every plugin comes from Nix. Plugins
# are pinned by nixpkgs (we accept its versions); the three not packaged there
# (ember, pretty_hover, tiny-code-action) are built from flake inputs below.
#
# The look/feel is deliberately unchanged from the lazy.nvim config: same `ember`
# colorscheme, same options/keymaps/autocmds (ported into opts/globals/keymaps and
# extraConfigLua), same plugin set and settings. Treesitter uses nixvim's typed
# module (main branch, grammars from Nix); everything bespoke is inlined as Lua so
# its behaviour is byte-identical to before. The actual programs.nixvim value lives
# in ./settings.nix so it can also be built standalone for testing.
#
# LSP servers / formatters / DAP adapters are provided to Neovim via extraPackages
# (Mason is not used — Mason-downloaded binaries break under NixOS dynamic linking).
# rust_analyzer is owned by rustaceanvim. The language toolchains/runtimes
# (cargo/rustc/rustfmt, gcc/gnumake, nodejs) still live in modules/home/dev and load
# alongside via modules/nixos/base/home.nix.
{
  inputs,
  lib,
  options,
  pkgs,
  ...
}:
let
  # Plugins not in nixpkgs, built from the pinned flake-input sources.
  ember = pkgs.vimUtils.buildVimPlugin {
    pname = "ember";
    version = "pinned";
    src = inputs.ember-theme;
  };
  pretty-hover = pkgs.vimUtils.buildVimPlugin {
    pname = "pretty_hover";
    version = "pinned";
    src = inputs.pretty-hover;
  };
  tiny-code-action = pkgs.vimUtils.buildVimPlugin {
    pname = "tiny-code-action.nvim";
    version = "pinned";
    src = inputs.tiny-code-action;
    # Optional previewer backend that only pulls snacks at require-check time.
    nvimSkipModules = [ "tiny-code-action.previewers.snacks" ];
  };
in
{
  imports = [ inputs.nixvim.homeModules.nixvim ];

  config = lib.mkMerge [
    {
      programs.nixvim = import ./settings.nix {
        inherit
          pkgs
          ember
          pretty-hover
          tiny-code-action
          ;
      };
    }

    # Stylix themes neovim via its generated init.lua; nixvim owns the colorscheme
    # (ember), so disable the stylix target where the option exists. Guarded because
    # stylix is only imported on desktop hosts (headless home-server has no stylix,
    # and defining an undeclared option is an eval error).
    (lib.optionalAttrs (options ? stylix) {
      stylix.targets.neovim.enable = false;
    })
  ];
}
