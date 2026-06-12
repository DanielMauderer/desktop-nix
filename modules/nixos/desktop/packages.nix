# System-level desktop services and the Bluetooth pairing GUI.
# User-facing desktop apps (waybar, rofi, wlogout, terminal, …) are installed
# per-user in home-manager; this file is only for things the system owns.
{ pkgs, ... }:
{
  services = {
    # Power profile switching backend for the waybar power-profile module
    # (replaces Fedora's tuned-adm). See pkgs/scripts/waybar-power-profile.sh.
    power-profiles-daemon.enable = true;

    # Bluetooth stack is enabled in base (DECISIONS 012); the desktop layer owns
    # the pairing GUI that waybar's bluetooth module opens on click.
    blueman.enable = true;

    # GNOME keyring unlocks secrets (Wi-Fi/VPN/app credentials) at login;
    # greetd has no keyring integration of its own.
    gnome.gnome-keyring.enable = true;

    # brightnessctl (used by the XF86MonBrightness key binds) ships udev rules
    # so users in the "video" group can set backlight without root.
    udev.packages = [ pkgs.brightnessctl ];
  };

  # swaylock authenticates via PAM; without this service it can never unlock.
  security.pam.services.swaylock = { };

  environment.systemPackages = [ pkgs.brightnessctl ];
  users.users.maudi.extraGroups = [ "video" ];
}
