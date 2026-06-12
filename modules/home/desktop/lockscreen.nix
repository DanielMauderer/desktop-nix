# Screen lock + idle handling: swaylock (the lock binary, standardised across
# the config — DECISIONS 016) driven by swayidle. swaybg paints the wallpaper
# and is launched from the Hyprland exec-once (path finalised in Ticket 05).
#
# swaylock-effects is used so the matugen-generated config in Ticket 05
# (image=, fade-in, grace-*) has the options it relies on. swaylock's PAM
# service is enabled system-side in modules/nixos/desktop.
{ pkgs, ... }:
{
  home.packages = [ pkgs.swaybg ];

  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock-effects;
    settings = {
      indicator-radius = 120;
      indicator-thickness = 7;
      grace = 0;
      fade-in = 0.1;
    };
  };

  services.swayidle = {
    enable = true;
    timeouts = [
      {
        timeout = 300;
        command = "${pkgs.swaylock-effects}/bin/swaylock";
      }
      {
        timeout = 600;
        command = "systemctl suspend";
      }
    ];
    events.before-sleep = "${pkgs.swaylock-effects}/bin/swaylock";
  };
}
