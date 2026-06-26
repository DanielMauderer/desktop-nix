# kitty terminal — ported from MyLinux kitty/kitty.conf.
#
# Colours and font are owned by stylix (DECISIONS 022): the old `include
# colors.conf` (matugen output) is dropped, and `font_family`/`font_size` are
# left to stylix.fonts.monospace. Window transparency (old background_opacity
# 0.7) is set the stylix way via `stylix.opacity.terminal` in the theming
# module, since stylix's kitty target writes `background_opacity` itself.
_: {
  programs.kitty.enable = true;

  programs.kitty.settings = {
    # Launch fish and show fastfetch if it is available.
    shell = "fish -C \"type -q fastfetch; and fastfetch\"";

    remember_window_size = "no";
    initial_window_width = 950;
    initial_window_height = 500;

    cursor_blink_interval = "0.5";
    cursor_stop_blinking_after = 1;
    cursor_trail_length = 1;

    scrollback_lines = 10000;
    wheel_scroll_min_lines = 1;

    # home-manager symlinks this config into /nix/store, and kitty's auto-reload
    # watcher recursively inotify-watches the resolved file's parent dir — i.e.
    # the whole store (~180k watches per window), which exhausts the per-user
    # inotify limit and breaks other watchers (e.g. waybar's battery module
    # crashes with "Could not watch events for .../BAT0"). The config is
    # declarative — a rebuild restarts kitty — so live reload buys nothing.
    # A negative value disables the watcher entirely.
    auto_reload_config = "-1";

    enable_audio_bell = "no";
    window_padding_width = 10;
    hide_window_decorations = "yes";
    dynamic_background_opacity = "yes";
    confirm_os_window_close = 0;

    selection_foreground = "none";
    selection_background = "none";

    # Per-user runtime socket (0700, owned by us) rather than world-accessible
    # /tmp; kitty expands $XDG_RUNTIME_DIR and appends the PID so instances do
    # not collide.
    allow_remote_control = "yes";
    listen_on = "unix:$XDG_RUNTIME_DIR/kitty";
  };
}
