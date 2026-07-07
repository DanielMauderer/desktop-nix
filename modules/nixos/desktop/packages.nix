{ pkgs, ... }:
{
  services = {
    # Backend for the waybar power-profile module.
    power-profiles-daemon.enable = true;

    # Bluetooth pairing GUI (waybar's bluetooth module opens it on click).
    blueman.enable = true;

    # Unlocks secrets (Wi-Fi/VPN/app credentials) at login; greetd has no
    # keyring integration of its own.
    gnome.gnome-keyring.enable = true;

    # udev rules so the "video" group can set backlight without root.
    udev.packages = [ pkgs.brightnessctl ];
  };

  # swaylock authenticates via PAM; without this it can never unlock.
  security.pam.services.swaylock = { };

  environment.systemPackages = [ pkgs.brightnessctl ];
  users.users.maudi.extraGroups = [ "video" ];
}
