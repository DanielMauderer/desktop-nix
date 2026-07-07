# The steam unfree allowance lives in the central list (modules/nixos/apps.nix).
{ pkgs, ... }:
{
  programs = {
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      gamescopeSession.enable = true;
      # Declarative Proton-GE, pinned by the flake (no imperative protonup step).
      extraCompatPackages = [ pkgs.proton-ge-bin ];
    };

    gamescope.enable = true;
    gamemode.enable = true;
  };
}
