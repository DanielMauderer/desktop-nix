# Per-user desktop environment (home-manager) — Ticket 04.
# Ported from the old MyLinux dotfiles, translated to native home-manager
# settings. Colour/theming (matugen) is deliberately left to Ticket 05; this
# module ships static fallback colours so the desktop is usable on its own.
{ pkgs, ... }:
{
  imports = [
    ./hyprland.nix
    ./waybar.nix
    ./dunst.nix
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
