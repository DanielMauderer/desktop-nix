# Launcher behaviour is native home-manager config; the visual theme stays a
# rasi file with a stylix-derived colour block prepended (stylix rofi target off).
{ config, pkgs, ... }:
let
  c = config.lib.stylix.colors.withHashtag;
  colorRasi = ''
    * {
        bg:           ${c.base00};
        bg-alt:       ${c.base01};
        bg-trans:     ${c.base00}ee;
        fg:           ${c.base05};
        fg-alt:       ${c.base04};
        fg-disabled:  ${c.base03};
        accent:       ${c.base0D};
        urgent:       ${c.base08};
        border:       ${c.base0D};
    }
  '';
  # toFile yields a store-path string, which the rofi module treats as a theme
  # path (a derivation like writeText would be misread as an inline attrset).
  rofiTheme = builtins.toFile "rofi-theme.rasi" (colorRasi + builtins.readFile ./rofi-theme.rasi);
in
{
  stylix.targets.rofi.enable = false;

  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    terminal = "${pkgs.kitty}/bin/kitty";
    theme = rofiTheme;
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
