# Application launcher. The launcher behaviour (modi, icons, fonts) is native
# home-manager config; the visual theme stays a rasi file (rofi-theme.rasi),
# ported from the old rofi/theme.rasi. The old theme's `@import "colors"`
# (matugen, Ticket 05) is replaced with static default colours at the top of
# that file so the launcher renders correctly on its own.
{ pkgs, ... }:
{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    terminal = "${pkgs.kitty}/bin/kitty";
    theme = ./rofi-theme.rasi;
    extraConfig = {
      modi = "drun,run,window,filebrowser";
      show-icons = true;
      display-drun = " Apps";
      display-run = " Run";
      display-window = " Windows";
      display-filebrowser = " Files";
      drun-display-format = "{name}";
      window-format = "{w} · {c} · {t}";
      font = "JetBrainsMono Nerd Font 11";
      icon-theme = "Papirus-Dark";
    };
  };
}
