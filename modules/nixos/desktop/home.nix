# Wire the per-user desktop configuration (Hyprland, waybar, …) into the
# home-manager instance that mkHost set up. Username is `maudi` on every
# machine (DECISIONS 007).
_: {
  home-manager.users.maudi.imports = [ ../../home/desktop ];
}
