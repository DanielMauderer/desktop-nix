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
  pkgs,
  inputs,
  osConfig,
  desktopScripts,
  ...
}:
let
  # "Last auto update" tracks the branch `system.autoUpgrade` actually pulls, so
  # the freshness widget always follows the real update source (single source of
  # truth). autoUpgrade.flake is a "github:owner/repo/branch" ref (enforced by
  # the flake assertions); split it into its parts, defaulting the branch.
  flakeParts = lib.splitString "/" (lib.removePrefix "github:" osConfig.system.autoUpgrade.flake);
  owner = builtins.elemAt flakeParts 0;
  repo = builtins.elemAt flakeParts 1;
  branch = if builtins.length flakeParts >= 3 then builtins.elemAt flakeParts 2 else "release";

  staleDays = config.local.updateStaleDays;

  # Thin wrapper baking the repo/branch/threshold into the packaged probe, so
  # the Luau widget just calls one argument-free path.
  checkScript = pkgs.writeShellScript "noctalia-last-update-check" ''
    export OWNER=${lib.escapeShellArg owner}
    export REPO=${lib.escapeShellArg repo}
    export BRANCH=${lib.escapeShellArg branch}
    export THRESHOLD_DAYS=${toString staleDays}
    exec ${desktopScripts.noctalia-last-update}/bin/noctalia-last-update
  '';

  # The plugin dir Noctalia scans (kind = "path" source below), with the wrapper
  # path substituted into main.luau's @CHECK_SCRIPT@ placeholder.
  pluginSrc = ../../../pkgs/noctalia-plugins/last-update;
  lastUpdatePlugin = pkgs.runCommand "noctalia-plugin-last-update" { } ''
    mkdir -p "$out"
    cp ${pluginSrc}/plugin.toml "$out/plugin.toml"
    substitute ${pluginSrc}/main.luau "$out/main.luau" \
      --replace-fail '@CHECK_SCRIPT@' '${checkScript}'
  '';
in
{
  imports = [ inputs.noctalia.homeModules.default ];

  # Per-host idle-to-suspend delay (work-laptop lengthens this). Lock is always
  # 300s; only the suspend timeout differs per machine.
  options.local.idleSuspendSeconds = lib.mkOption {
    type = lib.types.ints.positive;
    default = 600;
    description = "Seconds of inactivity before Noctalia suspends the machine.";
  };

  # Days without a new commit on the auto-update branch before the bar widget
  # goes red (the pipeline has likely stopped feeding the fleet).
  options.local.updateStaleDays = lib.mkOption {
    type = lib.types.ints.positive;
    default = 3;
    description = "Age (days) of the auto-update source before the bar widget turns red.";
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

        # Local "last auto-update" plugin (pkgs/noctalia-plugins/last-update),
        # scanned straight from its store path — no registry, no auto-update.
        plugins = {
          enabled = true;
          source = [
            {
              kind = "path";
              name = "last-update";
              location = "${lastUpdatePlugin}";
              enabled = true;
            }
          ];
        };

        # Place the widget in the bar's right group, just before control-center.
        # Setting `end` replaces the default list, so the built-ins are repeated
        # here verbatim with our widget inserted.
        bar.main.end = [
          "media"
          "tray"
          "notifications"
          "clipboard"
          "network"
          "bluetooth"
          "volume"
          "brightness"
          "battery"
          "danielmauderer/last-update:last-update"
          "control-center"
          "session"
        ];
      };
    };
  };
}
