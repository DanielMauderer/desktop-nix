# Screen lock + idle handling: swaylock (the lock binary, standardised across
# the config — DECISIONS 016) driven by swayidle. swaybg paints the wallpaper
# and is launched from the Hyprland exec-once.
#
# swaylock-effects is used so stylix's swaylock target (DECISIONS 022) can set
# image=/scaling/colours; the layout options below (indicator size, grace,
# fade-in) are kept on top. stylix points the lock screen at `stylix.image`
# automatically. swaylock's PAM service is enabled system-side in
# modules/nixos/desktop.
{ pkgs, ... }:
let
  # Lock guard: only spawn swaylock if one isn't already running, so a second
  # instance never stacks (e.g. the 300s idle timeout locks, then before-sleep
  # fires on suspend) — otherwise the screen has to be unlocked twice on resume.
  # `-f` forks after the lock surface is up so swayidle's -w is satisfied and
  # systemd can proceed with the actual suspend. pgrep/swaylock are pinned by
  # store path because the swayidle user service's PATH isn't guaranteed.
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
