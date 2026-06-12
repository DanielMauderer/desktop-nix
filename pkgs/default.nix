# Custom packages: the surviving shell scripts from the old MyLinux hypr/ and
# waybar/ dirs, each wrapped with writeShellApplication so shellcheck runs at
# build time and runtime dependencies are explicit.
#
# Scripts made obsolete by the migration are intentionally NOT packaged:
#   monitor-hotplug.sh, switch_hypr_env.sh  → replaced by kanshi
#   apply_matugen.sh                        → theming moves to Ticket 05
#   xdg.sh, loadconfig.sh                   → handled by systemd/xdg.portal
#   hypridle.sh, restart-hypridle.sh        → lock standardised on swayidle
#   power.sh, toggleallfloat.sh,            → unbound in the active config
#   systeminfo.sh, keybindings.sh
#
# hyprctl is resolved from the running Hyprland session at runtime, so it is
# deliberately left out of runtimeInputs (keeps these scripts' closures small).
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

  hypr-gamemode = app "hypr-gamemode" (with pkgs; [ libnotify ]);

  hypr-move-to = app "hypr-move-to" (with pkgs; [ jq ]);

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
