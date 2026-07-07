_: {
  virtualisation.waydroid.enable = true;

  # Float Android toplevels and the launcher, and inhibit idle while focused.
  home-manager.users.maudi.wayland.windowManager.hyprland.extraConfig = ''
    windowrule {
      name = wr-float-waydroid-class
      match:class = ^(waydroid.*)$
      float = true
    }
    windowrule {
      name = wr-float-waydroid-title
      match:title = ^(Waydroid)$
      float = true
    }
    windowrule {
      name = wr-idleinhibit-waydroid
      match:class = ^(waydroid.*)$
      idle_inhibit = focus
    }
  '';
}
