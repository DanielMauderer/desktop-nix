# Notifications — SwayNotificationCenter (DECISIONS 022), replacing dunst.
# swaync ships a slide-out control center (DND, history, media controls) and is
# themed by stylix's swaync target, so this module only owns layout/behaviour.
# It registers its own systemd user service (wanted by graphical-session.target),
# so no exec-once is needed.
_: {
  services.swaync = {
    enable = true;
    settings = {
      positionX = "right";
      positionY = "top";
      control-center-positionX = "right";
      control-center-positionY = "top";
      control-center-margin-top = 8;
      control-center-margin-bottom = 8;
      control-center-margin-right = 8;
      control-center-margin-left = 8;
      control-center-width = 380;
      notification-window-width = 380;
      notification-icon-size = 48;
      notification-body-image-height = 160;
      notification-body-image-width = 200;
      timeout = 8;
      timeout-low = 5;
      timeout-critical = 0;
      fit-to-screen = true;
      keyboard-shortcuts = true;
      image-visibility = "when-available";
      transition-time = 200;
      hide-on-clear = true;
      hide-on-action = true;
      script-fail-notify = true;
    };
  };
}
