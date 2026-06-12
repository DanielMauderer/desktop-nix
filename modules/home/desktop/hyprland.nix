# Hyprland, translated from the old MyLinux hypr/ config tree into native
# home-manager settings (wayland.windowManager.hyprland.settings).
#
# The session binary and portal come from the system (programs.hyprland, which
# uses the upstream Hyprland flake — DECISIONS 006), so package/portalPackage
# are null here: this module only owns ~/.config/hypr.
#
# Colours: the $material* variables below are static defaults lifted from the
# old colors.conf. Ticket 05 (theming) replaces them with matugen output from a
# writable path; until then they keep the gradient borders working.
{
  config,
  pkgs,
  desktopScripts,
  ...
}:
let
  inherit (builtins) genList map toString;

  workspaceKey = n: if n == 10 then "0" else toString n;
  workspaces = genList (i: i + 1) 10;

  # SUPER+<n> → switch, SUPER+SHIFT+<n> → move window, SUPER+CTRL+<n> → move all.
  workspaceBinds = map (n: "$mainMod, ${workspaceKey n}, workspace, ${toString n}") workspaces;
  moveToWorkspaceBinds = map (
    n: "$mainMod SHIFT, ${workspaceKey n}, movetoworkspace, ${toString n}"
  ) workspaces;
  moveAllBinds = map (
    n:
    "$mainMod CTRL, ${workspaceKey n}, exec, ${desktopScripts.hypr-move-to}/bin/hypr-move-to ${toString n}"
  ) workspaces;

  # Material You palette (old hypr/colors.conf). Referenced by the gradient
  # border colours below. Replaced by matugen in Ticket 05.
  colors = {
    "$primary" = "rgba(abc7ffff)";
    "$secondary" = "rgba(bec6dcff)";
    "$tertiary" = "rgba(ddbce0ff)";
    "$surface_variant" = "rgba(44474eff)";
    "$outline_variant" = "rgba(44474eff)";
  };
in
{
  home.pointerCursor = {
    name = "Bibata-Modern-Ice";
    package = pkgs.bibata-cursors;
    size = 24;
    gtk.enable = true;
  };

  wayland.windowManager.hyprland = {
    enable = true;
    # Provided by the system (modules/nixos/desktop/hyprland.nix).
    package = null;
    portalPackage = null;
    systemd.enable = true;
    # Keep the hyprlang config generator (the settings below are hyprlang, not
    # the new Lua format that becomes the default at stateVersion 26.05).
    configType = "hyprlang";

    settings = colors // {
      "$mainMod" = "SUPER";

      # Generic fallback; real per-output geometry is applied by kanshi
      # (modules/home/desktop/kanshi.nix). Per-host workspace→monitor rules
      # land in hosts/<name>/ in Tickets 13–15.
      monitor = [ ",preferred,auto,1" ];

      env = [
        "XDG_SESSION_TYPE,wayland"
        "XDG_SESSION_DESKTOP,Hyprland"
        "QT_QPA_PLATFORM,wayland;xcb"
        "QT_QPA_PLATFORMTHEME,qt6ct"
        "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
        "QT_AUTO_SCREEN_SCALE_FACTOR,1"
        "GDK_SCALE,1"
        "GDK_BACKEND,wayland,x11,*"
        "CLUTTER_BACKEND,wayland"
        "XCURSOR_SIZE,24"
        "OZONE_PLATFORM,wayland"
        "ELECTRON_OZONE_PLATFORM_HINT,wayland"
        "SDL_VIDEODRIVER,wayland"
      ];

      exec-once = [
        "hyprctl setcursor Bibata-Modern-Ice 24"
        "systemctl --user start hyprpolkitagent.service"
        # Wallpaper path is finalised in Ticket 05; swaybg simply no-ops if the
        # cache file is not present yet.
        "swaybg -i ${config.home.homeDirectory}/.config/hypr/cache/current_wallpaper.png -m fill"
      ];

      input = {
        kb_layout = "eu";
        numlock_by_default = true;
        mouse_refocus = false;
        follow_mouse = 1;
        sensitivity = 0;
        touchpad = {
          natural_scroll = false;
          scroll_factor = 1.0;
        };
      };

      general = {
        border_size = 3;
        "col.active_border" = "$primary $tertiary $secondary $primary 45deg";
        "col.inactive_border" = "$surface_variant $outline_variant 45deg";
        resize_on_border = true;
        extend_border_grab_area = 15;
        hover_icon_on_border = true;
        gaps_in = 4;
        gaps_out = 8;
        gaps_workspaces = 0;
        layout = "dwindle";
        allow_tearing = false;
      };

      decoration = {
        rounding = 12;
        active_opacity = 1.0;
        inactive_opacity = 0.92;
        fullscreen_opacity = 1.0;
        dim_inactive = true;
        dim_strength = 0.1;
        dim_special = 0.3;
        dim_around = 0.4;
        blur = {
          enabled = true;
          size = 8;
          passes = 3;
          new_optimizations = true;
          ignore_opacity = true;
          xray = false;
          noise = 0.02;
          contrast = 1.0;
          brightness = 1.0;
          vibrancy = 0.2;
          vibrancy_darkness = 0.2;
          special = true;
          popups = true;
          popups_ignorealpha = 0.2;
        };
        shadow = {
          enabled = true;
          range = 25;
          render_power = 3;
          color = "rgba(00000055)";
          color_inactive = "rgba(00000033)";
          offset = "0 4";
          scale = 1.0;
        };
      };

      animations = {
        enabled = true;
        bezier = [
          "md3_standard, 0.2, 0, 0, 1"
          "md3_decel, 0.05, 0.7, 0.1, 1"
          "md3_accel, 0.3, 0, 0.8, 0.15"
          "overshot, 0.05, 0.9, 0.1, 1.1"
          "smooth, 0.25, 0.1, 0.25, 1"
          "snappy, 0.4, 0, 0.2, 1"
          "expo, 0.87, 0, 0.13, 1"
        ];
        animation = [
          "windowsIn, 1, 4, md3_decel, popin 60%"
          "windowsOut, 1, 3, md3_accel, popin 60%"
          "windowsMove, 1, 4, md3_standard, slide"
          "fadeIn, 1, 3, md3_decel"
          "fadeOut, 1, 2, md3_accel"
          "fadeSwitch, 1, 3, md3_standard"
          "fadeShadow, 1, 3, md3_standard"
          "fadeDim, 1, 4, md3_standard"
          "fadeLayers, 1, 3, md3_decel"
          "border, 1, 10, md3_standard"
          "borderangle, 1, 100, linear, loop"
          "workspaces, 1, 5, md3_decel, slide"
          "specialWorkspace, 1, 4, md3_decel, slidefadevert -50%"
          "layers, 1, 3, md3_decel, popin 80%"
        ];
      };

      dwindle.preserve_split = true;

      binds = {
        workspace_back_and_forth = true;
        allow_workspace_cycles = true;
        pass_mouse_when_bound = false;
      };

      gestures = {
        workspace_swipe = true;
        workspace_swipe_fingers = 3;
        workspace_swipe_distance = 500;
        workspace_swipe_invert = false;
        workspace_swipe_min_speed_to_force = 30;
        workspace_swipe_cancel_ratio = 0.5;
        workspace_swipe_create_new = true;
        workspace_swipe_forever = true;
      };

      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        initial_workspace_tracking = 1;
      };

      # Unified windowrule syntax (string list). Ported from the old
      # windowrules/default.conf and ml4w.conf; swaync/nwg rules dropped
      # (dunst + kanshi replace them).
      windowrule = [
        "tile, title:^(Microsoft-edge)$"
        "tile, title:^(Brave-browser)$"
        "tile, title:^(Chromium)$"
        "float, title:^(nm-connection-editor)$"
        "float, title:^(qalculate-gtk)$"
        "idleinhibit fullscreen, class:.*"

        # Picture-in-Picture: floating, pinned, parked top-right.
        "float, title:^(Picture-in-Picture)$"
        "pin, title:^(Picture-in-Picture)$"
        "move 69.5% 4%, title:^(Picture-in-Picture)$"
        "opacity 1.0 override, title:^(Picture-in-Picture)$"

        # pavucontrol
        "float, class:^(.*org.pulseaudio.pavucontrol.*)$"
        "size 700 600, class:^(.*org.pulseaudio.pavucontrol.*)$"
        "center, class:^(.*org.pulseaudio.pavucontrol.*)$"
        "pin, class:^(.*org.pulseaudio.pavucontrol.*)$"

        # blueman-manager
        "float, class:^(blueman-manager)$"
        "size 800 600, class:^(blueman-manager)$"
        "center, class:^(blueman-manager)$"

        # Mission Center
        "float, class:^(io.missioncenter.MissionCenter)$"
        "pin, class:^(io.missioncenter.MissionCenter)$"
        "center, class:^(io.missioncenter.MissionCenter)$"
        "size 900 600, class:^(io.missioncenter.MissionCenter)$"

        # GNOME Calculator
        "float, class:^(org.gnome.Calculator)$"
        "size 700 600, class:^(org.gnome.Calculator)$"
        "center, class:^(org.gnome.Calculator)$"

        # Emoji picker (smile)
        "float, class:^(it.mijorus.smile)$"
        "pin, class:^(it.mijorus.smile)$"
        "move 100%-w-40 90, class:^(it.mijorus.smile)$"

        # Hyprland screen-share picker
        "float, class:^(hyprland-share-picker)$"
        "pin, class:^(hyprland-share-picker)$"
        "center, class:^(hyprland-share-picker)$"
        "size 600 400, class:^(hyprland-share-picker)$"

        # Generic floating helper window
        "float, class:^(dotfiles-floating)$"
        "size 1000 700, class:^(dotfiles-floating)$"
        "center, class:^(dotfiles-floating)$"
      ];

      layerrule = [
        "noanim, hyprpicker"
        "noanim, selection"
      ];

      bindm = [
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];

      binde = [
        "ALT, Tab, cyclenext"
        "ALT, Tab, bringactivetotop"
      ];

      bind = [
        # Applications
        "$mainMod, RETURN, exec, kitty"
        "$mainMod, B, exec, flatpak run app.zen_browser.zen"
        "$mainMod, E, exec, thunar"

        # Window management
        "$mainMod, Q, killactive"
        "$mainMod SHIFT, Q, exec, hyprctl activewindow | grep pid | tr -d 'pid:' | xargs kill"
        "$mainMod, F, fullscreen, 0"
        "$mainMod, M, fullscreen, 1"
        "$mainMod, T, togglefloating"
        "$mainMod SHIFT, T, workspaceopt, allfloat"
        "$mainMod, J, layoutmsg, togglesplit"
        "$mainMod, G, togglegroup"
        "$mainMod, K, layoutmsg, swapsplit"
        "$mainMod, left, movefocus, l"
        "$mainMod, right, movefocus, r"
        "$mainMod, up, movefocus, u"
        "$mainMod, down, movefocus, d"
        "$mainMod SHIFT, right, resizeactive, 100 0"
        "$mainMod SHIFT, left, resizeactive, -100 0"
        "$mainMod SHIFT, down, resizeactive, 0 100"
        "$mainMod SHIFT, up, resizeactive, 0 -100"
        "$mainMod ALT, left, swapwindow, l"
        "$mainMod ALT, right, swapwindow, r"
        "$mainMod ALT, up, swapwindow, u"
        "$mainMod ALT, down, swapwindow, d"

        # Actions
        "$mainMod CTRL, R, exec, hyprctl reload"
        "$mainMod, SPACE, exec, pkill rofi || rofi -show drun -replace -i"
        "$mainMod, L, exec, swaylock"
        "$mainMod, S, exec, hyprshot -m region --clipboard-only --freeze"
        "$mainMod SHIFT, S, exec, hyprshot -m window --clipboard-only"
        "$mainMod, Z, exec, ${desktopScripts.hypr-focus-mode}/bin/hypr-focus-mode"

        # Workspace navigation
        "$mainMod, Tab, workspace, m+1"
        "$mainMod SHIFT, Tab, workspace, m-1"
        "$mainMod, mouse_down, workspace, e+1"
        "$mainMod, mouse_up, workspace, e-1"
        "$mainMod CTRL, down, workspace, empty"

        # Media / brightness keys
        ", XF86MonBrightnessUp, exec, brightnessctl -q s +5%"
        ", XF86MonBrightnessDown, exec, brightnessctl -q s 5%-"
        ", XF86AudioRaiseVolume, exec, pactl set-sink-mute @DEFAULT_SINK@ 0 && pactl set-sink-volume @DEFAULT_SINK@ +5%"
        ", XF86AudioLowerVolume, exec, pactl set-sink-mute @DEFAULT_SINK@ 0 && pactl set-sink-volume @DEFAULT_SINK@ -5%"
        ", XF86AudioMute, exec, pactl set-sink-mute @DEFAULT_SINK@ toggle"
        ", XF86AudioMicMute, exec, pactl set-source-mute @DEFAULT_SOURCE@ toggle"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioPause, exec, playerctl pause"
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPrev, exec, playerctl previous"
        ", XF86Lock, exec, swaylock"
        ", code:238, exec, brightnessctl -d smc::kbd_backlight s +10"
        ", code:237, exec, brightnessctl -d smc::kbd_backlight s 10-"
      ]
      ++ workspaceBinds
      ++ moveToWorkspaceBinds
      ++ moveAllBinds;
    };
  };
}
