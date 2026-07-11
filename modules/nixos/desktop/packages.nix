{ pkgs, ... }:
{
  services = {
    # Backend for Noctalia's power-profile control + OSD.
    power-profiles-daemon.enable = true;

    # Battery/power state for Noctalia's battery widget and idle handling.
    upower.enable = true;

    # Bluetooth pairing GUI (floated by a window rule; Noctalia handles toggling).
    blueman.enable = true;

    # Unlocks secrets (Wi-Fi/VPN/app credentials) at login; greetd has no
    # keyring integration of its own.
    gnome.gnome-keyring.enable = true;

    # udev rules so the "video" group can set backlight without root.
    udev.packages = [ pkgs.brightnessctl ];
  };

  # Noctalia's lock screen authenticates against the standard "login" PAM
  # service, which NixOS provides by default — no dedicated PAM service needed.

  environment.systemPackages = [ pkgs.brightnessctl ];
  users.users.maudi.extraGroups = [ "video" ];
}
