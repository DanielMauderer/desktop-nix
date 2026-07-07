{ pkgs, ... }:
{
  home.packages = with pkgs; [
    thunar # SUPER+E file manager
    hyprshot # SUPER+S / SUPER+SHIFT+S screenshots
    hyprpolkitagent # polkit auth agent (started via exec-once)
    wl-clipboard # clipboard backend for hyprshot
    pavucontrol # audio mixer (waybar pulseaudio on-click)
    playerctl # media key binds + waybar custom/mpris script
    wireplumber # wpctl for the volume key binds (PipeWire-native)
    networkmanagerapplet # nm-applet + nm-connection-editor
    papirus-icon-theme # icon theme used by rofi
    libnotify # notify-send for the packaged scripts
    jq # JSON parsing for the SUPER+SHIFT+Q kill bind
  ];
}
