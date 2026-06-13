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
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
    }
  ]
  ++ (if withChaotic then [ chaotic.nixosModules.default ] else [ ])
  ++ modules;
}
