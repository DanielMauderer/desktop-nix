# Waydroid (Ticket 16) — Android container, opt-in per host.
#
# Parity with maudiblue, which layered the `waydroid` rpm into the image
# (recipes/recipe.yml). On NixOS this becomes `virtualisation.waydroid.enable`,
# which pulls in the waydroid package, the lxc/lxc-templates tooling and the
# binder kernel bits, and registers waydroid-container.service.
#
# Imported only from the hosts that want Android apps — private-laptop and
# desktop (DECISIONS 040) — NOT from modules/nixos/base and NOT by work-laptop,
# whose security policy has no place for an Android runtime.
#
# What stays imperative (one-time, per machine, not declarative):
#   * `sudo waydroid init`         — downloads the system + vendor images
#                                    (add `-s GAPPS` for the Google-Play image;
#                                    that path needs device registration, see
#                                    the open question in DECISIONS 040).
#   * `waydroid session start`     — starts the Android session.
#   * `waydroid show-full-ui`      — the full launcher; individual apps show as
#                                    their own toplevels in multi-window mode.
#   * Android data lives in        — ~/.local/share/waydroid (user-owned, kept
#     /var/lib/waydroid + the user   out of the nix store).
#     share dir.
_: {
  virtualisation.waydroid.enable = true;

  # Hyprland integration (multi-window mode). Waydroid renders each Android app
  # as its own Wayland toplevel; in multi-window mode their app_id/class is
  # `waydroid.<android.package.name>`, and the launcher's full UI is `Waydroid`.
  # Float them so a phone-shaped Android window doesn't get stretched into a
  # tiling slot, and keep the screen awake while one is focused (videos/games
  # don't emit idle-inhibit themselves). These rules are contributed from here
  # so they only land on waydroid hosts; the home module's shared windowrule
  # list (modules/home/desktop/hyprland.nix) concatenates with them.
  home-manager.users.maudi.wayland.windowManager.hyprland.extraConfig = ''
    windowrule {
      name = wr-float-waydroid-class
      match:class = ^(waydroid.*)$
      float = true
    }
    windowrule {
      name = wr-float-waydroid-title
      match:title = ^(Waydroid)$
      float = true
    }
  '';
}
