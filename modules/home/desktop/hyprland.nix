# Hyprland, translated from the old MyLinux hypr/ config tree into native
# home-manager settings (wayland.windowManager.hyprland.settings).
#
# The session binary and portal come from the system (programs.hyprland, which
# uses the upstream Hyprland flake — DECISIONS 006), so package/portalPackage
# are null here: this module only owns ~/.config/hypr.
#
# Colours: the gradient-border variables below are sourced from the stylix
# base16 palette (DECISIONS 022). stylix's own hyprland target is disabled (see
# below) so it does not flatten the multi-stop gradient into a single colour or
# pull in hyprpaper — swaybg keeps painting `stylix.image`.
{
  config,
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

  # Gradient-border palette, derived from the stylix base16 colours so the
  # borders track the wallpaper. base0D/0C/0E are the accent hues, base02/03
  # the muted surface/outline tones the inactive border used.
  c = config.lib.stylix.colors;
  colors = {
    "$primary" = "rgba(${c.base0D}ff)";
    "$secondary" = "rgba(${c.base0C}ff)";
    "$tertiary" = "rgba(${c.base0E}ff)";
    "$surface_variant" = "rgba(${c.base02}ff)";
    "$outline_variant" = "rgba(${c.base03}ff)";
  };
in
{
  # Cursor is owned by stylix.cursor (modules/nixos/desktop/theming.nix), which
  # sets home.pointerCursor for us.

  # stylix would otherwise theme hyprland (single-colour borders + hyprpaper);
  # we drive the gradient borders ourselves and keep swaybg, so turn it off.
  stylix.targets.hyprland.enable = false;

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
        "OZONE_PLATFORM,wayland"
        "ELECTRON_OZONE_PLATFORM_HINT,wayland"
        "SDL_VIDEODRIVER,wayland"
      ];

      exec-once = [
        "systemctl --user start hyprpolkitagent.service"
        # swaybg paints the stylix wallpaper (a store path; the picker swaps it
        # live and triggers a rebuild that re-derives the palette).
        "swaybg -i ${config.stylix.image} -m fill"
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

      # gestures.workspace_swipe_* were removed in Hyprland 0.47; the new
      # touch-gesture system has no equivalent knobs yet.

      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        initial_workspace_tracking = 1;
      };

      # windowrule unified syntax (Hyprland 0.47+: v1/v2 keywords both removed;
      # use `windowrule`; booleans need explicit `true`; idleinhibit removed).
      windowrule = [
        "float true, title ^(nm-connection-editor)$"
        "float true, title ^(qalculate-gtk)$"

        # Picture-in-Picture: floating, pinned, parked top-right.
        "float true, title ^(Picture-in-Picture)$"
        "pin true, title ^(Picture-in-Picture)$"
        "move 69.5% 4%, title ^(Picture-in-Picture)$"
        "opacity 1.0 override, title ^(Picture-in-Picture)$"

        # pavucontrol
        "float true, class ^(.*org.pulseaudio.pavucontrol.*)$"
        "size 700 600, class ^(.*org.pulseaudio.pavucontrol.*)$"
        "center true, class ^(.*org.pulseaudio.pavucontrol.*)$"
        "pin true, class ^(.*org.pulseaudio.pavucontrol.*)$"

        # blueman-manager
        "float true, class ^(blueman-manager)$"
        "size 800 600, class ^(blueman-manager)$"
        "center true, class ^(blueman-manager)$"

        # Mission Center
        "float true, class ^(io.missioncenter.MissionCenter)$"
        "pin true, class ^(io.missioncenter.MissionCenter)$"
        "center true, class ^(io.missioncenter.MissionCenter)$"
        "size 900 600, class ^(io.missioncenter.MissionCenter)$"

        # GNOME Calculator
        "float true, class ^(org.gnome.Calculator)$"
        "size 700 600, class ^(org.gnome.Calculator)$"
        "center true, class ^(org.gnome.Calculator)$"

        # Hyprland screen-share picker
        "float true, class ^(hyprland-share-picker)$"
        "pin true, class ^(hyprland-share-picker)$"
        "center true, class ^(hyprland-share-picker)$"
        "size 600 400, class ^(hyprland-share-picker)$"

        # Generic floating helper window
        "float true, class ^(dotfiles-floating)$"
        "size 1000 700, class ^(dotfiles-floating)$"
        "center true, class ^(dotfiles-floating)$"
      ];

      # noanim was removed as a layerrule type in Hyprland 0.47.

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
        "$mainMod SHIFT, Q, exec, hyprctl activewindow -j | jq -r '.pid' | xargs -r kill"
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
        "$mainMod, W, exec, ${desktopScripts.theme-wallpaper-select}/bin/theme-wallpaper-select"

        # Workspace navigation
        "$mainMod, Tab, workspace, m+1"
        "$mainMod SHIFT, Tab, workspace, m-1"
        "$mainMod, mouse_down, workspace, e+1"
        "$mainMod, mouse_up, workspace, e-1"
        "$mainMod CTRL, down, workspace, empty"

        # Media / brightness keys
        ", XF86MonBrightnessUp, exec, brightnessctl -q s +5%"
        ", XF86MonBrightnessDown, exec, brightnessctl -q s 5%-"
        ", XF86AudioRaiseVolume, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 && wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 && wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
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
