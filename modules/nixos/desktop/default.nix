# Desktop stack — imported by every host (Ticket 04, Machines: all).
# The NixOS side registers the Hyprland session, greeter, portals and polkit
# agent; the per-user Hyprland/waybar/etc. config lives in home-manager and is
# wired in by ./home.nix.
_: {
  imports = [
    ./hyprland.nix
    ./greetd.nix
    ./packages.nix
    ./theming.nix
    ./home.nix
  ];
}
