# kanshi applies the first profile whose outputs are all connected. Host-specific
# multi-output profiles live in hosts/<name>/ and are mkBefore-prepended so they
# match before this generic single-panel fallback.
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
