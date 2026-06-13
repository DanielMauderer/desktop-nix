# Application launcher. The launcher behaviour (modi, icons, fonts) is native
# home-manager config; the visual theme stays a rasi file (rofi-theme.rasi),
# ported from the old rofi/theme.rasi. The old theme's `@import "colors"`
# (matugen) becomes the colour block prepended below from the stylix palette
# (DECISIONS 022); stylix's own rofi target is disabled so it doesn't override
# the custom layout.
{ config, pkgs, ... }:
let
  c = config.lib.stylix.colors.withHashtag;
  # The palette `* { … }` block the old theme expected from @import "colors".
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
  # builtins.toFile yields a store-path *string*; home-manager's rofi module
  # treats that as a theme path and writes `@theme "<path>"` into config.rasi.
  # (A derivation, e.g. pkgs.writeText, is misread as an inline rasi attrset.)
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
