# Monitor profiles via kanshi (DECISIONS 017). Replaces the old
# monitor-hotplug.sh / switch_hypr_env.sh cycle scripts: kanshi watches for
# output hotplug and applies the first profile whose outputs are all connected,
# so dock/undock on the work-laptop "just works" with no keybind.
#
# Profiles are ordered most-specific first. Output names/modes are lifted from
# the old hypr/conf/monitors/*.conf; Tickets 13–15 verify them on hardware.
# Per-host workspace→monitor assignment is layered in those host tickets.
_: {
  services.kanshi = {
    enable = true;
    systemdTarget = "hyprland-session.target";
    settings = [
      {
        profile = {
          name = "desktop";
          outputs = [
            {
              criteria = "DP-3";
              mode = "2560x1440@144";
              position = "0,0";
            }
            {
              criteria = "DP-2";
              mode = "1920x1080@60";
              position = "2560,0";
            }
          ];
        };
      }
      {
        profile = {
          name = "work-laptop-docked-dual";
          outputs = [
            {
              criteria = "eDP-1";
              status = "disable";
            }
            {
              criteria = "DP-5";
              position = "0,0";
            }
            {
              criteria = "DP-6";
              position = "2560,0";
            }
          ];
        };
      }
      {
        profile = {
          name = "work-laptop-docked-hdmi";
          outputs = [
            {
              criteria = "eDP-1";
              position = "0,0";
            }
            {
              criteria = "HDMI-A-1";
              position = "1920,0";
            }
          ];
        };
      }
      {
        profile = {
          name = "laptop-internal";
          outputs = [
            {
              criteria = "eDP-1";
              status = "enable";
            }
          ];
        };
      }
    ];
  };
}
