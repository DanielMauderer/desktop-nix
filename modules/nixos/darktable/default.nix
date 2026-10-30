# darktable — RAW photo editor, opt-in per host.
#
# Imported only from the hosts that want it — private-laptop and desktop — and
# NOT from modules/nixos/base and NOT by work-laptop.
{ pkgs, ... }:
{
  home-manager.users.maudi.home.packages = [ pkgs.darktable ];
}
