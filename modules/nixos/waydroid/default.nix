_: {
  virtualisation.waydroid.enable = true;

  # Float Android toplevels and the launcher, and inhibit idle while focused.
  # Hyprland 0.56+ reads Lua only, so these are hl.window_rule calls rather than
  # the old hyprlang `windowrule { … }` blocks.
  home-manager.users.maudi.wayland.windowManager.hyprland.extraConfig = ''
    hl.window_rule({
      name = "wr-float-waydroid-class",
      match = { class = "^(waydroid.*)$" },
      float = true,
    })
    hl.window_rule({
      name = "wr-float-waydroid-title",
      match = { title = "^(Waydroid)$" },
      float = true,
    })
    hl.window_rule({
      name = "wr-idleinhibit-waydroid",
      match = { class = "^(waydroid.*)$" },
      idle_inhibit = "focus",
    })
  '';
}
