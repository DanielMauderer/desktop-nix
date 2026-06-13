# Per-user desktop environment (home-manager) — Ticket 04, themed in Ticket 05.
# Ported from the old MyLinux dotfiles, translated to native home-manager
# settings. Colours come from stylix (DECISIONS 022): stylix themes most apps
# directly, while waybar/wlogout/rofi/hyprland keep their custom layouts and
# source colours from `config.lib.stylix.colors`.
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

  # The packaged hypr/waybar scripts (pkgs/) are shared across the modules
  # below via this module argument.
  _module.args.desktopScripts = import ../../../pkgs { inherit pkgs; };

  home.stateVersion = "25.05";
}
