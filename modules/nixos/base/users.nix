# Primary user. Username is `maudi` on every machine (DECISIONS 007).
# fish is the login shell — replaces the `chsh` step in maudiblue's setup.sh.
# `initialPassword` is a bootstrap convenience only; Ticket 12 (secrets)
# replaces it with a managed hash. Per-feature groups (libvirtd, gamemode)
# are added by their own modules.
{ pkgs, lib, ... }:
{
  programs.fish.enable = true;

  users.users.maudi = {
    isNormalUser = true;
    description = "maudi";
    shell = pkgs.fish;
    extraGroups = [
      "wheel"
      "networkmanager"
      "dialout"
    ];
    initialPassword = lib.mkDefault "changeme";
  };
}
