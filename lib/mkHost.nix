{
  inputs,
  nixpkgs,
  home-manager,
  chaotic,
}:
{
  modules,
  system ? "x86_64-linux",
  withChaotic ? false,
}:
nixpkgs.lib.nixosSystem {
  inherit system;
  specialArgs = { inherit inputs; };
  # stylix/sops-nix/disko NixOS modules are added here rather than imported from
  # the modules that read `inputs` — the latter infinitely recurses when the
  # nixosTest nodes supply `inputs` through `_module.args`. It also keeps
  # hosts/*/disk.nix argument-free (disko is invoked standalone at install time
  # without flake inputs).
  modules = [
    home-manager.nixosModules.home-manager
    inputs.stylix.nixosModules.stylix
    inputs.sops-nix.nixosModules.sops
    inputs.disko.nixosModules.disko
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = { inherit inputs; };
      };
    }
  ]
  ++ (if withChaotic then [ chaotic.nixosModules.default ] else [ ])
  ++ modules;
}
