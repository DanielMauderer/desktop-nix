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
  ...
}:
let
  # The root Noctalia scans (kind = "path" source below). It scans the
  # SUBDIRECTORIES of a source location for plugin.toml, so every plugin gets
  # its own dir in here — pointing the source straight at a plugin dir finds
  # nothing.
  pluginRoot = pkgs.runCommand "noctalia-plugins" { } ''
    mkdir -p "$out"
    cp -r ${inputs.noctalia-community-plugins}/nix-monitor "$out/nix-monitor"
    chmod -R u+w "$out/nix-monitor"
    # Upstream compares against a nixpkgs branch head, which is always ahead of
    # the CI-gated release lock autoUpgrade follows — a permanent false
    # "Update available". Compare against the nixpkgs rev release pins instead.
    substituteInPlace "$out/nix-monitor/nix_monitor_service.luau" \
      --replace-fail '"git ls-remote https://github.com/NixOS/nixpkgs " .. branch .. " 2>/dev/null' \
                     '"${releaseNixpkgsRev} 2>/dev/null'
  '';

  # The flake system.autoUpgrade builds (modules/nixos/core/updates.nix).
  releaseFlake = "github:DanielMauderer/desktop-nix/release";

  # Prints the nixpkgs rev locked on the release branch.
  releaseNixpkgsRev = pkgs.writeShellScript "release-nixpkgs-rev" ''
    ${lib.getExe pkgs.curl} -fsSL https://raw.githubusercontent.com/DanielMauderer/desktop-nix/release/flake.lock \
      | ${lib.getExe pkgs.jq} -r '.nodes[.nodes.root.inputs.nixpkgs].locked.rev'
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

  config = {
    # Noctalia is the launcher, so rofi is unused. stylix's rofi target still
    # writes the renamed `programs.rofi.font` and triggers an eval warning.
    stylix.targets.rofi.enable = false;

    programs.noctalia = {
      enable = true;
      # User service started with the Hyprland graphical session.
      systemd.enable = true;

      settings = {
        # Noctalia's own UI colours are generated from the current wallpaper,
        # matching the stylix palette that themes the apps.
        theme = {
          mode = "dark";
          # Force our value over the upstream module's default (newer noctalia
          # revisions set theme.source = "custom"); we want wallpaper-derived UI.
          source = lib.mkForce "wallpaper";
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
        # Native actions, not commands: `action` defaults to "command", which
        # runs `command` through /bin/sh, and Noctalia no longer resolves the
        # old `noctalia:` prefix there — that string silently never locked.
        idle.behavior = {
          lock = {
            enabled = true;
            timeout = 300;
            action = "lock";
          };
          suspend = {
            enabled = true;
            timeout = config.local.idleSuspendSeconds;
            action = "lock_and_suspend";
          };
        };

        # Plugins are scanned straight from one store path — declaring any source
        # replaces Noctalia's built-in official/community git sources, so nothing
        # is cloned or auto-updated at runtime.
        # `enabled` is the opt-in list of active plugin ids (author/plugin), not a
        # boolean; the source must also be enabled to be scanned.
        plugins = {
          auto_update = "none";
          enabled = [ "avivbintangaringga/nix-monitor" ];
          source = [
            {
              kind = "path";
              name = "declarative";
              location = "${pluginRoot}";
              enabled = true;
            }
          ];
        };

        # Plugin-level settings (own top-level table, keyed by plugin id). The
        # remote check is patched (pluginRoot) to read release's locked nixpkgs
        # rev, so `branch` is only a panel label now. The Update button builds
        # the same flake as autoUpgrade, never the local checkout, whose lock
        # can lag behind and would roll the system back.
        plugin_settings."avivbintangaringga/nix-monitor" = {
          branch = "nixos-unstable";
          update_command = "sudo nixos-rebuild switch --flake ${releaseFlake}";
        };

        # Place the plugin widget in the bar's right group, just before
        # control-center. Setting `end` replaces the default list, so the
        # built-ins are repeated here verbatim with our widget inserted.
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
          "avivbintangaringga/nix-monitor:nix-monitor"
          "control-center"
          "session"
        ];
      };
    };
  };
}
