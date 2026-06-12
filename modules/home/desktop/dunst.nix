# Notification daemon. The old dunst/ dir held no committed config — colours
# were generated at runtime by apply_matugen.sh — so this is a clean, sensible
# default. Ticket 05 layers matugen colours on top.
{ pkgs, ... }:
{
  services.dunst = {
    enable = true;
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    settings = {
      global = {
        font = "JetBrainsMono Nerd Font 10";
        frame_width = 2;
        corner_radius = 12;
        offset = "12x12";
        origin = "top-right";
        width = 350;
        gap_size = 6;
        markup = "full";
        format = "<b>%s</b>\n%b";
      };
      urgency_low.timeout = 5;
      urgency_normal.timeout = 8;
      urgency_critical.timeout = 0;
    };
  };
}
