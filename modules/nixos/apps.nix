{
  inputs,
  pkgs,
  lib,
  ...
}:
{
  # Single authoritative unfree allow-list (only one may be defined per host).
  # Listing steam here only permits it — nothing installs it on the laptops.
  # The predicate is asked about every derivation, so wrapper packages need
  # their `-unwrapped` (and friends) listed too, not just the wrapper's name.
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "spotify"
      "claude-code"
      "discord"
      "discord-unwrapped"
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
