# Monitor management via kanshi (DECISIONS 017). Replaces the old
# monitor-hotplug.sh / switch_hypr_env.sh cycle scripts: kanshi watches for
# output hotplug and applies the first profile whose outputs are all connected,
# so dock/undock "just works" with no keybind or config-dir writes.
#
# This shared module only enables kanshi and ships the generic single-panel
# fallback. Host-specific multi-output profiles (desktop dual-head, work-laptop
# dock/undock) live in hosts/<name>/default.nix and are prepended with
# lib.mkBefore so they match before this fallback. Output names/modes are
# verified on hardware in Tickets 13–15.
_: {
  services.kanshi = {
    enable = true;
    systemdTarget = "hyprland-session.target";
    settings = [
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
