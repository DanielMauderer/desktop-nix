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
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
    }
  ]
  ++ (if withChaotic then [ chaotic.nixosModules.default ] else [ ])
  ++ modules;
}
