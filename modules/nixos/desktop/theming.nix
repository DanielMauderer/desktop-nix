# Theming — Stylix (Ticket 05 / DECISIONS 022).
#
# Stylix derives one base16 palette from `stylix.image` at build time and
# themes the whole desktop declaratively. Because home-manager runs as a NixOS
# module, stylix's home-manager integration copies `stylix.*` into the maudi
# home automatically, so this one module themes both system and home.
#
# Wallpaper change == rebuild: the rofi wallpaper picker
# (pkgs/scripts/theme-wallpaper-select.sh) overwrites ./wallpaper.png in the
# local flake checkout and runs `nixos-rebuild switch`, which re-derives the
# palette. The committed default below is what every host falls back to (and
# what `system.autoUpgrade` restores, since it builds from git main).
#
# Stylix owns GTK, Qt (qtct → kvantum under the hood), kitty, swaync, swaylock,
# the cursor, fonts and icons. The Wayland apps with hand-tuned layouts from
# Ticket 04 (waybar, wlogout, rofi, hyprland) keep their own CSS/settings but
# source their colours from `config.lib.stylix.colors`; their stylix targets
# are disabled in the matching home modules so stylix does not fight the custom
# layouts.
{ inputs, pkgs, ... }:
{
  imports = [ inputs.stylix.nixosModules.stylix ];

  stylix = {
    enable = true;
    polarity = "dark";

    # Default wallpaper; the picker replaces this file and rebuilds. Stylix
    # generates the palette from it and points swaylock/swaybg at it too.
    image = ./wallpaper.png;
    imageScalingMode = "fill";

    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 24;
    };

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };
      sansSerif = {
        package = pkgs.cantarell-fonts;
        name = "Cantarell";
      };
      serif = {
        package = pkgs.cantarell-fonts;
        name = "Cantarell";
      };
      sizes = {
        applications = 11;
        terminal = 11;
        desktop = 10;
        popups = 10;
      };
    };

    icons = {
      enable = true;
      package = pkgs.papirus-icon-theme;
      dark = "Papirus-Dark";
    };
  };
}
