# Waybar, translated from the old waybar/config.jsonc into native settings.
# Only the modules actually placed on the bar are ported; the many unused
# module definitions in the old config are dropped. Script on-clicks point at
# the packaged wrappers in pkgs/. Runs as a systemd user service bound to the
# Hyprland session.
{ desktopScripts, ... }:
let
  floatTop = "kitty --class dotfiles-floating -e fish -c 'top; exec fish'";
in
{
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    style = builtins.readFile ./waybar-style.css;

    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 25;
      margin-left = 5;
      margin-right = 5;
      margin-top = 5;
      margin-bottom = 0;
      spacing = 15;
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
        "mpris"
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

      clock = {
        format = "{:%H:%M}";
        tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        format-alt = "{:%Y-%m-%d}";
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

      mpris = {
        format = "{player_icon} {title} - {artist} ";
        format-paused = "{status_icon} {title} - {artist}";
        player-icons.default = "󰝚 ";
        status-icons.paused = "󰏤 ";
        tooltip-format = "Playing: {title} - {artist}";
        min-length = 5;
        max-length = 18;
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
