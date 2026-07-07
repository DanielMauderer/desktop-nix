{ pkgs, ... }:
{
  stylix = {
    enable = true;
    polarity = "dark";

    # Palette source; the rofi picker replaces this file and rebuilds.
    image = ./wallpaper.png;
    imageScalingMode = "fill";

    # Set here because stylix's kitty target owns `background_opacity`.
    opacity.terminal = 0.7;

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
