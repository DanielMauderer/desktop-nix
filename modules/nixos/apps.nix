{
  inputs,
  pkgs,
  lib,
  ...
}:
{
  # Single authoritative unfree allow-list (only one may be defined per host).
  # Listing steam here only permits it — nothing installs it on the laptops.
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "spotify"
      "claude-code"
      "discord"
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
