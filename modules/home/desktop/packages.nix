{ pkgs, ... }:
{
  home.packages = with pkgs; [
    thunar # SUPER+E file manager
    hyprshot # SUPER+S / SUPER+SHIFT+S screenshots
    hyprpolkitagent # polkit auth agent (started via exec-once)
    wl-clipboard # clipboard backend for hyprshot
    pavucontrol # audio mixer (float rule; Noctalia control-center on-click)
    playerctl # play/pause/next/prev media key binds
    networkmanagerapplet # nm-connection-editor (floated by a window rule)
    libnotify # notify-send for the packaged scripts
    jq # JSON parsing for the SUPER+SHIFT+Q kill bind + wallpaper-sync script
  ];
}
