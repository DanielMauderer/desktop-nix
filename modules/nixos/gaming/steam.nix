# Steam + gaming runtime (Ticket 11, desktop only). See DECISIONS 034.
#
# The unfree allowance for steam/steam-unwrapped lives in the single central
# allow-list (modules/nixos/apps.nix, DECISIONS 029) — only one module may
# define nixpkgs.config.allowUnfreePredicate per host, so it is not repeated
# here. (proton-ge-bin and steam-run are already free.)
{ pkgs, ... }:
{
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
    # as unused (DECISIONS 034).
    gamemode.enable = true;
  };
}
