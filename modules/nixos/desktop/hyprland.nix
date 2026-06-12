# Hyprland session registration plus the desktop's system-level prerequisites:
# XDG portals, polkit, dconf. Hyprland itself comes from the upstream flake
# (DECISIONS 006); the user config is managed by home-manager.
{ inputs, pkgs, ... }:
let
  hyprPkgs = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  programs.hyprland = {
    enable = true;
    package = hyprPkgs.hyprland;
    portalPackage = hyprPkgs.xdg-desktop-portal-hyprland;
  };

  # polkit agent (hyprpolkitagent) runs in the user session; it needs the
  # system polkit daemon enabled. hyprpolkitagent itself is installed and
  # started from home-manager (modules/home/desktop).
  security.polkit.enable = true;

  # File-chooser / screenshot portals. programs.hyprland already wires the
  # Hyprland portal; gtk covers GTK file pickers used by most apps.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # GTK/GSettings backend used by many Wayland apps and the theming layer.
  programs.dconf.enable = true;
}
