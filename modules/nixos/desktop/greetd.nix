# Greeter: greetd + tuigreet (DECISIONS 015). A minimal Wayland-native TUI
# greeter that launches the Hyprland session for the selected user.
{ pkgs, ... }:
{
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --asterisks --cmd Hyprland";
      user = "greeter";
    };
  };
}
