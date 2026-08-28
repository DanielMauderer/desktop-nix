# Neovim configured declaratively with nixvim. Plugins come from nixpkgs; the
# three not packaged there are built from flake inputs below. The programs.nixvim
# value lives in ./settings.nix so it can also be built standalone for testing.
{
  config,
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

    {
      # We make nixvim's nixpkgs input follow ours (one nixpkgs in the closure),
      # so state the source explicitly rather than letting nixvim warn that its
      # pinned default was overridden by the `follows`.
      programs.nixvim.nixpkgs.source = inputs.nixpkgs;
    }

    {
      # Only the parsers actually used, not nixvim's default of *all* grammars
      # (~300 derivations added to every host closure).
      programs.nixvim.plugins.treesitter.grammarPackages =
        with config.programs.nixvim.plugins.treesitter.package.builtGrammars; [
          angular
          bash
          c
          cpp
          css
          diff
          dockerfile
          go
          gomod
          gosum
          html
          javascript
          json
          lua
          luadoc
          markdown
          markdown_inline
          python
          query
          regex
          rust
          scss
          toml
          tsx
          typescript
          vim
          vimdoc
          yaml
        ];
    }

    # Disable stylix's nixvim target so it doesn't override the `ember`
    # colorscheme. Guarded because stylix is absent on the headless home-server.
    (lib.optionalAttrs (options ? stylix) {
      stylix.targets.nixvim.enable = false;
    })
  ];
}
