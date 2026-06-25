# GUI applications (Ticket 10) — all machines.
# Decision matrix: Spotify via nixpkgs unfree (DECISIONS 029), Zen Browser via
# 0xc000022070/zen-browser-flake twilight channel (DECISIONS 030), no flatpak
# on NixOS (DECISIONS 031/032). mpv and imv cover video and image viewing.
{
  inputs,
  pkgs,
  lib,
  ...
}:
{
  # Exact unfree allow-list: any undeclared unfree package fails the build.
  # This is the single authoritative gate (DECISIONS 029) — keep it here rather
  # than scattering per-module predicates (only one may define this option per
  # host). Steam is desktop-only (Ticket 11 / DECISIONS 034); listing its names
  # here only *permits* them — nothing installs steam on the laptops.
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "spotify"
      "claude-code"
      "steam"
      "steam-unwrapped"
      "steam-original"
      "steam-run"
    ];

  home-manager.users.maudi.home.packages = [
    pkgs.spotify
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.twilight
    pkgs.mpv
    pkgs.imv
  ];
}
