{ pkgs, ... }:
{
  imports = [
    ./hyprland.nix
    ./noctalia.nix
    ./kanshi.nix
    ./packages.nix
  ];

  # Shared packaged hypr scripts (pkgs/) for the modules below.
  _module.args.desktopScripts = import ../../../pkgs { inherit pkgs; };
}
