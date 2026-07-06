# Discord — chat client, opt-in per host.
#
# Ships `vesktop`, the community Discord client, rather than the official
# `discord` package: vesktop is free/open-source (so no allowUnfreePredicate
# entry is needed, unlike the unfree upstream client) and does Wayland
# screenshare-with-audio, which the official client does not.
#
# Imported only from the hosts that want it — private-laptop and desktop — the
# same opt-in set as modules/nixos/waydroid, and NOT from modules/nixos/base and
# NOT by work-laptop.
{ pkgs, ... }:
{
  home-manager.users.maudi.home.packages = [ pkgs.vesktop ];
}
