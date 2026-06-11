# lib/mkHost.nix — wraps nixpkgs.lib.nixosSystem with home-manager and shared specialArgs.
# Usage: (import ./lib/mkHost.nix { inherit nixpkgs home-manager; }) { hostName = …; … }
{ nixpkgs, home-manager }:
{
  hostName,
  system ? "x86_64-linux",
  username,
  modules ? [ ],
  extraSpecialArgs ? { },
}:
nixpkgs.lib.nixosSystem {
  inherit system;
  specialArgs = { inherit username; } // extraSpecialArgs;
  modules = [
    home-manager.nixosModules.home-manager
    {
      networking.hostName = hostName;
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users.${username}.home.stateVersion = "25.05";
      };
    }
  ] ++ modules;
}
