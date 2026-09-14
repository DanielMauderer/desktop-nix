# kanshi applies the first profile whose outputs exactly match the connected set
# (every profile output connected, and no extra output connected). Host-specific
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
