# GUI applications (Ticket 10) — all machines.
# Decision matrix: Spotify via nixpkgs unfree (DECISIONS 029), Zen Browser via
# 0xc000022070/zen-browser-flake twilight channel (DECISIONS 030), no flatpak
# on NixOS (DECISIONS 031/032). mpv and imv cover video and image viewing.
# See docs/tickets/10-flatpak-strategy.md for the full rationale.
{
  inputs,
  pkgs,
  lib,
  ...
}:
{
  # Exact unfree allow-list: any undeclared unfree package fails the build.
  # Steam entries (steam, steam-unwrapped, steam-run) are added in Ticket 11.
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "spotify"
    ];

  home-manager.users.maudi.home.packages = [
    pkgs.spotify
    inputs.zen-browser.packages.${pkgs.system}.twilight
    pkgs.mpv
    pkgs.imv
  ];
}
