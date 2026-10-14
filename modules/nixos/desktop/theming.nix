{ pkgs, ... }:
{
  stylix = {
    enable = true;
    polarity = "dark";

    # Palette source; theme-sync-wallpaper replaces this file and rebuilds.
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
      # Not Cantarell: Chromium/Electron can't load its variable OTF, so
      # `system-ui` (the GTK font) fell back to FreeMono in Teams & co.
      sansSerif = {
        package = pkgs.noto-fonts;
        name = "Noto Sans";
      };
      serif = {
        package = pkgs.noto-fonts;
        name = "Noto Sans";
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
