# Noctalia — the Wayland desktop shell. Replaces waybar (bar), rofi (launcher),
# swaync (notifications + control center), swaylock (lock), swayidle (idle →
# auto-lock/suspend), swaybg (wallpaper) and wlogout (session menu), and adds
# volume/brightness OSD overlays.
#
# Theming split (see DECISIONS): Noctalia colours its OWN UI from the wallpaper
# (theme.source = "wallpaper"), while stylix keeps deriving the app palette from
# the SAME image (config.stylix.image). Both track one declared wallpaper.
#
# The upstream home module (imported below) auto-sets programs.noctalia.package;
# settings are written to ~/.config/noctalia/config.toml and validated at build.
{
  config,
  lib,
  inputs,
  ...
}:
{
  imports = [ inputs.noctalia.homeModules.default ];

  # Per-host idle-to-suspend delay (work-laptop lengthens this). Lock is always
  # 300s; only the suspend timeout differs per machine.
  options.local.idleSuspendSeconds = lib.mkOption {
    type = lib.types.ints.positive;
    default = 600;
    description = "Seconds of inactivity before Noctalia suspends the machine.";
  };

  config = {
    programs.noctalia = {
      enable = true;
      # User service started with the Hyprland graphical session.
      systemd.enable = true;

      settings = {
        # Noctalia's own UI colours are generated from the current wallpaper,
        # matching the stylix palette that themes the apps.
        theme = {
          mode = "dark";
          source = "wallpaper";
          wallpaper_scheme = "m3-content";
        };

        # Noctalia draws the wallpaper (replaces swaybg). Default to the stylix
        # image so both engines start from the same picture; runtime changes go
        # through the wallpaper panel (SUPER+W) + theme-sync-wallpaper.
        wallpaper = {
          enabled = true;
          default.path = "${config.stylix.image}";
        };

        # Idle: lock at 5 min, suspend after (per-host). Replaces swayidle.
        idle.behavior = {
          lock = {
            enabled = true;
            timeout = 300;
            command = "noctalia:session lock";
          };
          suspend = {
            enabled = true;
            timeout = config.local.idleSuspendSeconds;
            command = "systemctl suspend";
          };
        };
      };
    };
  };
}
