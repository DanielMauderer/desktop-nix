{
  inputs,
  nixpkgs,
  home-manager,
  chaotic,
}:
{
  hostname,
  modules,
  system ? "x86_64-linux",
  withChaotic ? false,
}:
nixpkgs.lib.nixosSystem {
  inherit system;
  specialArgs = { inherit inputs hostname; };
  modules = [
    home-manager.nixosModules.home-manager
    # stylix's NixOS module is added here (not via an `inputs` module arg
    # inside theming.nix's `imports`, which would infinitely recurse when the
    # nixosTest node provides `inputs` through `_module.args`). The theming
    # module only sets `stylix.*` config.
    inputs.stylix.nixosModules.stylix
    # sops-nix's NixOS module is added here (like stylix) rather than via an
    # `imports` inside modules/nixos/core/secrets.nix that reads `inputs` from
    # `_module.args`, which would infinitely recurse when the nixosTest node
    # provides `inputs` through `_module.args`. The secrets module only sets
    # `sops.*` config (the age key source).
    inputs.sops-nix.nixosModules.sops
    # disko's NixOS module is added here (like stylix/sops-nix) so that
    # hosts/*/disk.nix can be plain, argument-free modules. When disko is
    # invoked standalone at install time (`nix run … disko -- --mode disko
    # disk.nix`) it does NOT pass flake `inputs` to the module, so a disk.nix
    # that does `{ inputs, ... }: { imports = [ inputs.disko… ]; }` fails with
    # "function called without required argument 'inputs'". Putting the import
    # here means disk.nix only needs to set `disko.devices.*`.
    inputs.disko.nixosModules.disko
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        # Flake inputs reach the home-manager modules (the neovim module imports
        # nixvim's home module and builds a few unpackaged plugins from inputs).
        extraSpecialArgs = { inherit inputs; };
      };
    }
  ]
  ++ (if withChaotic then [ chaotic.nixosModules.default ] else [ ])
  ++ modules;
}
