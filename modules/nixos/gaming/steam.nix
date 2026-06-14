# Steam + gaming runtime (Ticket 11, desktop only). See DECISIONS 029.
{ pkgs, lib, ... }:
{
  # Steam (and its steam-unwrapped payload) are unfree. Scope the allowance to
  # exactly the gaming packages instead of a blanket allowUnfree — this module
  # is desktop-only, so the laptops keep a fully-free package set. (proton-ge-bin
  # and steam-run are already free; listed here only so the predicate is robust
  # if upstream relicenses.)
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "steam"
      "steam-unwrapped"
      "steam-original"
      "steam-run"
      "proton-ge-bin"
    ];

  programs = {
    steam = {
      enable = true;
      # Open the ports Steam Remote Play / In-Home Streaming needs.
      remotePlay.openFirewall = true;
      # Offer a "Steam (gamescope)" Big-Picture session at the greeter.
      gamescopeSession.enable = true;
      # Declarative Proton-GE: pinned by the flake, no imperative protonup step.
      # Appears in Steam as "GE-Proton" under a title's compatibility settings.
      extraCompatPackages = [ pkgs.proton-ge-bin ];
    };

    # Micro-compositor for upscaling / frame-limiting individual games.
    gamescope.enable = true;

    # feralinteractive gamemode: launch a game with `gamemoderun %command%` (or
    # via Steam's launch options) to apply CPU governor / niceness / GPU perf
    # tweaks for its lifetime. The old cosmetic hypr-gamemode toggle was dropped
    # as unused (DECISIONS 029).
    gamemode.enable = true;
  };
}
