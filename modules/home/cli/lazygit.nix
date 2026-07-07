# Config vendored verbatim via xdg.configFile rather than `programs.lazygit`,
# whose unconditional config.yml.source would collide with the vendored file.
{ pkgs, ... }:
{
  home.packages = [ pkgs.lazygit ];

  xdg.configFile."lazygit/config.yml".source = ./config.yml;
}
