# Pure-Nix unit tests for modules/home/neovim/default.nix.
#
# `pkgs.vimUtils.buildVimPlugin` is overridden to an identity+tag function so
# the three plugins built from flake inputs (ember/pretty-hover/
# tiny-code-action) come back as plain attrsets we can inspect instead of
# real derivations — nothing here needs to actually build a plugin, only
# prove default.nix wires the right pname/src/extra options through.
# `pkgs.vimPlugins` (used by the real ./settings.nix, still invoked for real
# underneath) is left untouched. `inputs` and `options` are otherwise
# mocked. The `config` half of the module is `lib.mkMerge [...]`, so
# assertions read its `.contents` list directly rather than resolving it
# through a full module-system eval. Wired into flake.nix as the
# `unit-nvim-default-check` check via `mkUnitCheck`.
{ lib, pkgs }:
let
  taggedBuildVimPlugin = args: args // { __mockBuilt = true; };
  mockPkgs = pkgs // {
    vimUtils = pkgs.vimUtils // {
      buildVimPlugin = taggedBuildVimPlugin;
    };
  };

  mkArgs = options: {
    inputs = {
      nixvim.homeModules.nixvim = "MOCK_NIXVIM_HOME_MODULE";
      ember-theme = "MOCK_EMBER_SRC";
      pretty-hover = "MOCK_PRETTY_HOVER_SRC";
      tiny-code-action = "MOCK_TINY_CODE_ACTION_SRC";
    };
    inherit lib options;
    pkgs = mockPkgs;
  };

  withStylix = import ./default.nix (mkArgs { stylix = { }; });
  withoutStylix = import ./default.nix (mkArgs { });

  firstMerge = m: builtins.elemAt m.config.contents 0;
  secondMerge = m: builtins.elemAt m.config.contents 1;

  nixvimCfg = (firstMerge withStylix).programs.nixvim;
  ember = lib.findFirst (p: (p.pname or null) == "ember") null nixvimCfg.extraPlugins;
  prettyHover = lib.findFirst (p: (p.pname or null) == "pretty_hover") null nixvimCfg.extraPlugins;
  tinyCodeAction = lib.findFirst (
    p: (p.pname or null) == "tiny-code-action.nvim"
  ) null nixvimCfg.extraPlugins;
in
[
  {
    name = "imports the nixvim home-manager module";
    assertion = withStylix.imports == [ "MOCK_NIXVIM_HOME_MODULE" ];
  }
  {
    name = "config is a two-entry mkMerge";
    assertion = withStylix.config._type == "merge" && builtins.length withStylix.config.contents == 2;
  }
  {
    name = "programs.nixvim is set from settings.nix";
    assertion = (firstMerge withStylix).programs ? nixvim;
  }
  {
    name = "the ported look/feel (ember colorscheme) survives the wiring";
    assertion = nixvimCfg.colorscheme == "ember" && nixvimCfg.enable == true;
  }
  {
    name = "ember plugin is built from the ember-theme input";
    assertion = ember != null && ember.version == "pinned" && ember.src == "MOCK_EMBER_SRC" && ember.__mockBuilt;
  }
  {
    name = "pretty_hover plugin is built from the pretty-hover input";
    assertion = prettyHover != null && prettyHover.src == "MOCK_PRETTY_HOVER_SRC";
  }
  {
    name = "tiny-code-action plugin is built from its input and skips the snacks previewer module";
    assertion =
      tinyCodeAction != null
      && tinyCodeAction.src == "MOCK_TINY_CODE_ACTION_SRC"
      && tinyCodeAction.nvimSkipModules == [ "tiny-code-action.previewers.snacks" ];
  }
  {
    name = "stylix neovim target is disabled when the stylix option exists";
    assertion = secondMerge withStylix == {
      stylix.targets.neovim.enable = false;
    };
  }
  {
    name = "stylix guard contributes nothing when the stylix option is absent";
    assertion = secondMerge withoutStylix == { };
  }
]