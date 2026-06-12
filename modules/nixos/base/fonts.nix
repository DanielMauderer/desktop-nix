# System fonts. Nerd Fonts + Google Fonts ported from maudiblue (INVENTORY §3).
{ pkgs, ... }:
{
  fonts = {
    packages = with pkgs; [
      nerd-fonts.fira-code
      nerd-fonts.hack
      nerd-fonts.sauce-code-pro
      nerd-fonts.terminess-ttf
      nerd-fonts.jetbrains-mono
      nerd-fonts.symbols-only
      roboto
      open-sans
    ];

    fontconfig.defaultFonts = {
      monospace = [ "JetBrainsMono Nerd Font" ];
      sansSerif = [
        "Roboto"
        "Open Sans"
      ];
    };
  };
}
