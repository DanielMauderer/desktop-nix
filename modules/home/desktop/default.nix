{ pkgs, ... }:
{
  imports = [
    ./hyprland.nix
    ./waybar.nix
    ./swaync.nix
    ./rofi.nix
    ./wlogout.nix
    ./lockscreen.nix
    ./kanshi.nix
    ./packages.nix
  ];

  # Shared packaged hypr/waybar scripts (pkgs/) for the modules below.
  _module.args.desktopScripts = import ../../../pkgs { inherit pkgs; };
}
