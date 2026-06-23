# User-facing desktop apps and the CLI helpers the Hyprland binds / waybar
# modules call. Programs with their own home-manager module (waybar, rofi,
# wlogout, swaylock, dunst) are NOT listed here.
#
# kitty (the SUPER+RETURN terminal) is provided by `programs.kitty` in the cli
# module (Ticket 06). Flatpak apps (zen-browser, spotify, …) are Ticket 10.
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    thunar # SUPER+E file manager
    hyprshot # SUPER+S / SUPER+SHIFT+S screenshots
    hyprpolkitagent # polkit auth agent (started via exec-once)
    wl-clipboard # clipboard backend for hyprshot
    pavucontrol # audio mixer (waybar pulseaudio on-click)
    gsimplecal # calendar popup (waybar clock on-click); stylix themes its GTK UI
    playerctl # media key binds + waybar custom/mpris script
    wireplumber # wpctl for the volume key binds (PipeWire-native)
    networkmanagerapplet # nm-applet + nm-connection-editor
    papirus-icon-theme # icon theme used by rofi
    libnotify # notify-send for the packaged scripts
    jq # JSON parsing for the SUPER+SHIFT+Q kill bind
  ];
}
