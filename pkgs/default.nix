# The hypr/waybar helper scripts, each wrapped with writeShellApplication so
# shellcheck runs at build time and runtime dependencies are explicit.
#
# hyprctl (from the running session) and `sudo`/`nixos-rebuild` are resolved from
# the ambient PATH, so they're deliberately left out of runtimeInputs.
{ pkgs }:
let
  app =
    name: runtimeInputs:
    pkgs.writeShellApplication {
      inherit name runtimeInputs;
      text = builtins.readFile (./scripts + "/${name}.sh");
    };
in
{
  hypr-focus-mode = app "hypr-focus-mode" (
    with pkgs;
    [
      jq
      libnotify
      procps
    ]
  );

  hypr-move-to = app "hypr-move-to" (with pkgs; [ jq ]);

  theme-wallpaper-select = app "theme-wallpaper-select" (
    with pkgs;
    [
      rofi
      swaybg
      libnotify
      procps
      coreutils
      findutils
    ]
  );

  waybar-vpn-status = app "waybar-vpn-status" (
    with pkgs;
    [
      networkmanager
      gawk
    ]
  );

  waybar-vpn-toggle = app "waybar-vpn-toggle" (
    with pkgs;
    [
      networkmanager
      gawk
    ]
  );

  waybar-power-profile = app "waybar-power-profile" (
    with pkgs;
    [
      power-profiles-daemon
      libnotify
    ]
  );

  waybar-mpris = app "waybar-mpris" (
    with pkgs;
    [
      playerctl
      coreutils
    ]
  );

  waybar-networkmanager = app "waybar-networkmanager" (
    with pkgs;
    [
      kitty
      networkmanager
    ]
  );

  waybar-nm-applet = app "waybar-nm-applet" (
    with pkgs;
    [
      networkmanagerapplet
      procps
      psmisc
    ]
  );
}
