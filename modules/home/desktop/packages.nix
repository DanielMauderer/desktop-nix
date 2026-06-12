# User-facing desktop apps and the CLI helpers the Hyprland binds / waybar
# modules call. Programs with their own home-manager module (waybar, rofi,
# wlogout, swaylock, dunst) are NOT listed here.
#
# kitty is installed so the terminal bind works; its configuration is owned by
# Ticket 06. Flatpak apps (zen-browser, spotify, …) are Ticket 10.
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    kitty # SUPER+RETURN terminal (config: Ticket 06)
    thunar # SUPER+E file manager
    hyprshot # SUPER+S / SUPER+SHIFT+S screenshots
    hyprpicker # colour picker (layerrule)
    hyprpolkitagent # polkit auth agent (started via exec-once)
    wl-clipboard # clipboard backend for hyprshot
    pavucontrol # audio mixer (waybar pulseaudio on-click)
    playerctl # media key binds + waybar mpris
    pulseaudio # pactl client for the volume key binds
    networkmanagerapplet # nm-applet + nm-connection-editor
    papirus-icon-theme # icon theme used by rofi/dunst
    libnotify # notify-send for the packaged scripts
  ];
}
