# Colours, font and opacity are owned by stylix (see the theming module).
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

    # Disabled: the watcher would inotify-watch the whole nix store (config is a
    # store symlink), exhausting the per-user inotify limit and starving other
    # inotify users (e.g. the shell's config watchers).
    auto_reload_config = "-1";

    enable_audio_bell = "no";
    window_padding_width = 10;
    hide_window_decorations = "yes";
    dynamic_background_opacity = "yes";
    confirm_os_window_close = 0;

    selection_foreground = "none";
    selection_background = "none";

    # Per-user runtime socket rather than world-accessible /tmp.
    allow_remote_control = "yes";
    listen_on = "unix:$XDG_RUNTIME_DIR/kitty";
  };
}
