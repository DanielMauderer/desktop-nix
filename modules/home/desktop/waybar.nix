# Waybar, translated from the old waybar/config.jsonc into native settings.
# Only the modules actually placed on the bar are ported; the many unused
# module definitions in the old config are dropped. Script on-clicks point at
# the packaged wrappers in pkgs/. Runs as a systemd user service bound to the
# Hyprland session.
{ config, desktopScripts, ... }:
let
  floatTop = "kitty --class dotfiles-floating -e fish -c 'top; exec fish'";

  # Colours come from the stylix palette (DECISIONS 022). The stylix waybar
  # target is disabled below so it doesn't restyle the bar; instead we map the
  # base16 palette onto the semantic @define-color names waybar-style.css uses.
  c = config.lib.stylix.colors.withHashtag;
  colorCss = ''
    @define-color text ${c.base05};
    @define-color subtext ${c.base04};
    @define-color muted ${c.base03};
    @define-color surface2 ${c.base02};
    @define-color surface ${c.base01};
    @define-color base ${c.base00};
    @define-color accent ${c.base0D};
    @define-color accent2 ${c.base0C};
    @define-color tertiary ${c.base0E};
    @define-color red ${c.base08};
    @define-color green ${c.base0B};
    @define-color yellow ${c.base0A};
  '';
in
{
  stylix.targets.waybar.enable = false;

  programs.waybar = {
    enable = true;
    systemd.enable = true;
    style = colorCss + builtins.readFile ./waybar-style.css;

    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 25;
      margin-left = 5;
      margin-right = 5;
      margin-top = 5;
      margin-bottom = 0;
      spacing = 6;
      reload_style_on_change = true;

      modules-left = [
        "group/group-1"
        "group/group-9"
        "group/group-10"
      ];
      modules-center = [ "group/group-5" ];
      modules-right = [
        "group/group-4"
        "group/group-3"
        "group/group-2"
      ];

      "group/group-1".modules = [ "hyprland/workspaces" ];
      "group/group-9".modules = [
        "custom/mpris"
        "custom/previous"
        "custom/pause"
        "custom/next"
      ];
      "group/group-10".modules = [
        "idle_inhibitor"
        "custom/vpn"
      ];
      "group/group-5".modules = [ "hyprland/window" ];
      "group/group-4".modules = [
        "bluetooth"
        "battery"
        "network"
        "custom/power-profile"
        "custom/power"
      ];
      "group/group-3".modules = [
        "clock"
        "pulseaudio"
        "backlight"
      ];
      "group/group-2".modules = [
        "cpu"
        "temperature"
        "memory"
      ];

      "hyprland/workspaces" = {
        on-click = "activate";
        activate-only = false;
        all-outputs = true;
        format = "{name}";
        persistent-workspaces."*" = 3;
      };

      "hyprland/window" = {
        format = " 󰶞 {}";
        max-length = 32;
        separate-outputs = false;
      };

      # Time on the bar; the calendar is waybar's own, rendered inside the
      # themed tooltip and coloured straight from the stylix palette so it
      # matches the bar exactly (Pango markup needs literal hex, hence the
      # interpolation). Right-click toggles month/year; scroll changes month.
      clock = {
        format = "{:%H:%M}";
        format-alt = "{:%Y-%m-%d}";
        tooltip-format = "<span color='${c.base0D}'><b>{:%A, %d %B %Y}</b></span>\n<tt>{calendar}</tt>";
        calendar = {
          mode = "month";
          mode-mon-col = 3;
          weeks-pos = "right";
          on-scroll = 1;
          format = {
            months = "<span color='${c.base0D}'><b>{}</b></span>";
            days = "<span color='${c.base05}'>{}</span>";
            weekdays = "<span color='${c.base0C}'><b>{}</b></span>";
            today = "<span color='${c.base0A}'><b><u>{}</u></b></span>";
            weeks = "<span color='${c.base03}'>{}</span>";
          };
        };
        actions = {
          on-click-right = "mode";
          on-scroll-up = "shift_up";
          on-scroll-down = "shift_down";
        };
      };

      cpu = {
        interval = 2;
        format = " {usage:>2}%";
        on-click = floatTop;
      };

      temperature = {
        critical-threshold = 80;
        interval = 2;
        format = " {temperatureC:>2}°C";
        on-click = floatTop;
      };

      memory = {
        interval = 2;
        format = " {:>2}%";
      };

      backlight = {
        format = "{icon} {percent:>2}%";
        format-icons = [
          ""
          ""
          ""
          ""
          ""
          ""
          ""
          ""
          ""
        ];
      };

      bluetooth = {
        format = "{icon}";
        format-icons = [
          "󰂯"
          "󰤾"
          "󰥀"
          "󰥄"
          "󰥈"
        ];
        tooltip-format-off = "Bluetooth is off";
        tooltip-format-on = "Bluetooth is on";
        format-connected = "{icon} {num_connections}";
        on-click = "blueman-manager";
      };

      battery = {
        states = {
          good = 95;
          warning = 30;
          critical = 15;
        };
        format = "{icon} {capacity}%";
        format-full = "{icon}";
        format-plugged = " {capacity}%";
        format-icons = [
          ""
          ""
          ""
          ""
        ];
        tooltip-format = "{capacity}%, about {time} left";
      };

      network = {
        format = "{ifname}";
        format-wifi = "  {essid}";
        format-ethernet = "  {ifname}";
        format-disconnected = "Disconnected ⚠";
        max-length = 50;
        on-click = "${desktopScripts.waybar-networkmanager}/bin/waybar-networkmanager";
        on-click-right = "${desktopScripts.waybar-nm-applet}/bin/waybar-nm-applet toggle";
      };

      pulseaudio = {
        format = "{icon} {volume}%";
        format-bluetooth = "{icon} {volume}% 󰂯";
        format-muted = "󰖁 {volume}%";
        format-icons.default = [
          ""
          ""
          ""
        ];
        on-click = "pavucontrol";
      };

      idle_inhibitor = {
        format = "{icon}";
        format-icons = {
          activated = "󰅶";
          deactivated = "󰛊";
        };
      };

      # Now-playing via a hardened playerctl script instead of the built-in
      # `mpris` module, whose D-Bus metadata handling intermittently crashed the
      # whole bar (e.g. on Spotify track changes). The script escapes markup and
      # never exits non-zero, so a misbehaving player can't take the bar down.
      "custom/mpris" = {
        exec = "${desktopScripts.waybar-mpris}/bin/waybar-mpris";
        return-type = "json";
        format = "{}";
        on-click = "playerctl play-pause";
        on-scroll-up = "playerctl next";
        on-scroll-down = "playerctl previous";
        # The script already escapes Pango markup, so Waybar must not escape
        # again (escape = true would double-escape `&` into `&amp;`).
        escape = false;
        max-length = 40;
      };

      "custom/next" = {
        format = "󰙡 ";
        on-click = "playerctl next";
        tooltip = false;
      };
      "custom/pause" = {
        format = "{icon}";
        on-click = "playerctl play-pause";
        tooltip = false;
        format-icons = [
          ""
          ""
        ];
      };
      "custom/previous" = {
        format = "󰙣";
        on-click = "playerctl previous";
        tooltip = false;
      };

      "custom/vpn" = {
        exec = "${desktopScripts.waybar-vpn-status}/bin/waybar-vpn-status";
        interval = 5;
        on-click = "${desktopScripts.waybar-vpn-toggle}/bin/waybar-vpn-toggle";
        format = "{}";
      };

      "custom/power-profile" = {
        exec = "${desktopScripts.waybar-power-profile}/bin/waybar-power-profile";
        interval = 5;
        on-click = "${desktopScripts.waybar-power-profile}/bin/waybar-power-profile cycle";
        format = "{}";
        tooltip-format = "Power Profile (Click to cycle)";
      };

      "custom/power" = {
        format = "";
        on-click = "wlogout";
        tooltip-format = "Power Menu";
      };
    };
  };
}
