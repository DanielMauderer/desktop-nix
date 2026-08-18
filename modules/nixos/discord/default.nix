# Discord — chat client, opt-in per host.
#
# Ships the official `discord` package. We previously used `vesktop` (the
# community client) but its Wayland screenshare had no audio in practice, so we
# switched back to the upstream client. `discord` is unfree and is a wrapper
# around `discord-unwrapped`, so both names are allow-listed in
# modules/nixos/apps.nix (nixpkgs.config.allowUnfreePredicate) — the predicate
# runs per derivation, so allow-listing the wrapper alone leaves the build
# failing on its unwrapped dependency.
#
# Imported only from the hosts that want it — private-laptop and desktop — the
# same opt-in set as modules/nixos/waydroid, and NOT from modules/nixos/base and
# NOT by work-laptop.
{ pkgs, ... }:
{
  home-manager.users.maudi.home.packages = [ pkgs.discord ];
}
