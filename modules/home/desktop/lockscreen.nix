# swaylock (via swaylock-effects, so stylix themes it) driven by swayidle.
{ pkgs, ... }:
let
  # Guard so a second swaylock never stacks (idle-lock then before-sleep on
  # suspend) — otherwise the screen must be unlocked twice on resume. `-f` forks
  # after the surface is up so swayidle's -w is satisfied.
  lockOnce = "${pkgs.procps}/bin/pgrep -x swaylock || ${pkgs.swaylock-effects}/bin/swaylock -f";
in
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
        command = lockOnce;
      }
      {
        timeout = 600;
        command = "systemctl suspend";
      }
    ];
    events.before-sleep = lockOnce;
  };
}
