{
  config,
  lib,
  desktopScripts,
  ...
}:
let
  inherit (builtins)
    concatStringsSep
    genList
    map
    toJSON
    toString
    ;

  # Hyprland 0.56+ only reads ~/.config/hypr/hyprland.lua — the hyprlang config
  # manager and the hyprland.conf lookup were both removed upstream. Everything
  # below therefore targets the Lua API (hl.*), not the old hyprlang strings.
  #
  # home-manager renders `settings` as `hl.<attr>(<args>)` calls, alphabetically
  # except for `importantPrefixes` (which already hoists "curve" above
  # "animation", so curves are defined before animations reference them). The
  # `_args` wrapper below turns an attrset into Lua *call arguments* rather than
  # a single table argument.
  args = a: { _args = a; };

  # Lua string literal. JSON escaping is a compatible subset for our ASCII
  # commands, and keeps embedded quotes in shell one-liners safe.
  lua = toJSON;

  workspaceKey = n: if n == 10 then "0" else toString n;
  workspaces = genList (i: i + 1) 10;

  # Gradient-border palette, derived from the stylix base16 colours. The old
  # `$primary`-style hyprlang variables are gone: Lua has no config-level
  # variable indirection, so the colours are interpolated straight in.
  c = config.lib.stylix.colors;
  rgba = base: "rgba(${base}ff)";

  # --- keybinds ------------------------------------------------------------
  # Binds must be raw Lua: the second argument is a dispatcher *expression*
  # (hl.dsp.*), which the settings renderer can only ever emit as a string.
  # They therefore live in extraConfig, which is appended last.
  bind' =
    opts: key: dispatcher:
    "hl.bind(${lua key}, ${dispatcher}${lib.optionalString (opts != null) ", ${opts}"})";
  bind = bind' null;
  exec = cmd: "hl.dsp.exec_cmd(${lua cmd})";

  # Media/brightness keys must fire while the session is locked and repeat on
  # hold, matching the old binde/locked behaviour.
  mediaKey = bind' "{ locked = true, repeating = true }";
  # Mouse binds (old `bindm`). `mouse = true` is what routes the bind through the
  # pointer-button path; `{ drag = true }` parses but leaves the bind inert, so
  # SUPER+drag falls through to the client's own titlebar drag.
  dragBind = bind' "{ mouse = true }";

  direction = key: dir: bind "SUPER + ${key}" "hl.dsp.focus({ direction = ${lua dir} })";
  resize =
    key: x: y:
    bind "SUPER + SHIFT + ${key}" "hl.dsp.window.resize({ x = ${toString x}, y = ${toString y}, relative = true })";
  swap = key: dir: bind "SUPER + ALT + ${key}" "hl.dsp.window.swap({ direction = ${lua dir} })";

  # SUPER+<n> → switch, SUPER+SHIFT+<n> → move window, SUPER+CTRL+<n> → move all.
  workspaceBinds = map (
    n: bind "SUPER + ${workspaceKey n}" "hl.dsp.focus({ workspace = ${toString n} })"
  ) workspaces;
  moveToWorkspaceBinds = map (
    n: bind "SUPER + SHIFT + ${workspaceKey n}" "hl.dsp.window.move({ workspace = ${toString n} })"
  ) workspaces;
  moveAllBinds = map (
    n:
    bind "SUPER + CTRL + ${workspaceKey n}" (
      exec "${desktopScripts.hypr-move-to}/bin/hypr-move-to ${toString n}"
    )
  ) workspaces;

  binds = [
    "-- Applications"
    (bind "SUPER + RETURN" (exec "kitty"))
    (bind "SUPER + B" (exec "zen-twilight"))
    (bind "SUPER + E" (exec "thunar"))

    "\n-- Window management"
    (bind "SUPER + Q" "hl.dsp.window.close()")
    (bind "SUPER + SHIFT + Q" (exec "hyprctl activewindow -j | jq -r '.pid' | xargs -r kill"))
    # Defaults are mode = "fullscreen", action = "toggle" (old `fullscreen, 0`).
    (bind "SUPER + F" "hl.dsp.window.fullscreen()")
    (bind "SUPER + M" "hl.dsp.window.fullscreen({ mode = \"maximized\" })")
    (bind "SUPER + T" "hl.dsp.window.float({ action = \"toggle\" })")
    (bind "SUPER + J" "hl.dsp.layout(\"togglesplit\")")
    (bind "SUPER + G" "hl.dsp.group.toggle()")
    (bind "SUPER + K" "hl.dsp.layout(\"swapsplit\")")
    (direction "left" "left")
    (direction "right" "right")
    (direction "up" "up")
    (direction "down" "down")
    (resize "right" 100 0)
    (resize "left" (-100) 0)
    (resize "down" 0 100)
    (resize "up" 0 (-100))
    (swap "left" "left")
    (swap "right" "right")
    (swap "up" "up")
    (swap "down" "down")

    "\n-- Actions (Noctalia shell panels via IPC)"
    (bind "SUPER + CTRL + R" (exec "hyprctl reload"))
    (bind "SUPER + SPACE" (exec "noctalia msg panel-toggle launcher"))
    (bind "SUPER + N" (exec "noctalia msg panel-toggle control-center"))
    (bind "SUPER + X" (exec "noctalia msg panel-toggle session"))
    (bind "SUPER + V" (exec "noctalia msg panel-toggle clipboard"))
    (bind "SUPER + L" (exec "noctalia msg session lock"))
    (bind "SUPER + S" (exec "hyprshot -m region --clipboard-only --freeze"))
    (bind "SUPER + SHIFT + S" (exec "hyprshot -m window --clipboard-only"))
    (bind "SUPER + Z" (exec "${desktopScripts.hypr-focus-mode}/bin/hypr-focus-mode"))
    (bind "SUPER + W" (exec "noctalia msg panel-toggle wallpaper"))
    (bind "SUPER + SHIFT + W" (exec "${desktopScripts.theme-sync-wallpaper}/bin/theme-sync-wallpaper"))

    "\n-- Workspace navigation"
    (bind "SUPER + Tab" "hl.dsp.focus({ workspace = \"m+1\" })")
    (bind "SUPER + SHIFT + Tab" "hl.dsp.focus({ workspace = \"m-1\" })")
    (bind "SUPER + mouse_down" "hl.dsp.focus({ workspace = \"e+1\" })")
    (bind "SUPER + mouse_up" "hl.dsp.focus({ workspace = \"e-1\" })")
    (bind "SUPER + CTRL + down" "hl.dsp.focus({ workspace = \"empty\" })")

    "\n-- Window cycling. One handler running two dispatchers: a second hl.bind on"
    "-- the same key replaces the first rather than chaining onto it."
    ''
      hl.bind("ALT + Tab", function()
        hl.dispatch(hl.dsp.window.cycle_next())
        hl.dispatch(hl.dsp.window.bring_to_top())
      end, { repeating = true })''

    "\n-- Move/resize windows with SUPER + LMB/RMB"
    (dragBind "SUPER + mouse:272" "hl.dsp.window.drag()")
    (dragBind "SUPER + mouse:273" "hl.dsp.window.resize()")

    ''

      -- Media / brightness keys — volume & brightness go through Noctalia so its
      -- OSD overlay shows the change (replaces the old wpctl/brightnessctl binds).''
    (mediaKey "XF86MonBrightnessUp" (exec "noctalia msg brightness-up"))
    (mediaKey "XF86MonBrightnessDown" (exec "noctalia msg brightness-down"))
    (mediaKey "XF86AudioRaiseVolume" (exec "noctalia msg volume-up"))
    (mediaKey "XF86AudioLowerVolume" (exec "noctalia msg volume-down"))
    (mediaKey "XF86AudioMute" (exec "noctalia msg volume-mute"))
    (mediaKey "XF86AudioMicMute" (exec "noctalia msg mic-mute"))
    (bind "XF86AudioPlay" (exec "playerctl play-pause"))
    (bind "XF86AudioPause" (exec "playerctl pause"))
    (bind "XF86AudioNext" (exec "playerctl next"))
    (bind "XF86AudioPrev" (exec "playerctl previous"))
    # XF86Lock is not a real keysym (the old hyprlang config bound a no-op);
    # XF86ScreenSaver is the one the kernel/xkb actually emits.
    (bind "XF86ScreenSaver" (exec "noctalia msg session lock"))
    # Keyboard backlight (MacBook SMC) has no Noctalia equivalent — keep brightnessctl.
    (mediaKey "code:238" (exec "brightnessctl -d smc::kbd_backlight s +10"))
    (mediaKey "code:237" (exec "brightnessctl -d smc::kbd_backlight s 10-"))

    "\n-- Workspaces"
  ]
  ++ workspaceBinds
  ++ moveToWorkspaceBinds
  ++ moveAllBinds;
in
{
  # We drive the gradient borders ourselves, so disable stylix's hyprland target
  # (it would flatten borders and pull in hyprpaper). Noctalia draws the wallpaper.
  stylix.targets.hyprland.enable = false;

  wayland.windowManager.hyprland = {
    enable = true;
    # Session binary + portal come from the system module.
    package = null;
    portalPackage = null;
    systemd = {
      enable = true;
      # There is no hl.exec_once, and adding a second hl.on("hyprland.start")
      # handler alongside home-manager's own is needlessly subtle. Appending to
      # the session activation command keeps the ordering explicit.
      #
      # Setting this REPLACES the module default, so the two session-target
      # commands are repeated verbatim: dropping them leaves
      # hyprland-session.target inactive and nothing wired to it (noctalia,
      # kanshi) ever starts.
      extraCommands = [
        "systemctl --user stop hyprland-session.target"
        "systemctl --user start hyprland-session.target"
        "systemctl --user start hyprpolkitagent.service"
      ];
    };
    configType = "lua";

    settings = {
      # Generic fallback; real per-output geometry is applied by kanshi.
      monitor = [
        (args [
          {
            output = "";
            mode = "preferred";
            position = "auto";
            scale = 1;
          }
        ])
      ];

      # hl.env takes name and value as separate arguments, so each entry is a
      # two-element _args list — splitting the old "NAME,value" strings on the
      # first comma would have mangled GDK_BACKEND's own comma-separated value.
      env = map args [
        [
          "XDG_SESSION_TYPE"
          "wayland"
        ]
        [
          "XDG_SESSION_DESKTOP"
          "Hyprland"
        ]
        [
          "QT_QPA_PLATFORM"
          "wayland;xcb"
        ]
        [
          "QT_QPA_PLATFORMTHEME"
          "qt6ct"
        ]
        [
          "QT_WAYLAND_DISABLE_WINDOWDECORATION"
          "1"
        ]
        [
          "QT_AUTO_SCREEN_SCALE_FACTOR"
          "1"
        ]
        [
          "GDK_SCALE"
          "1"
        ]
        [
          "GDK_BACKEND"
          "wayland,x11,*"
        ]
        [
          "CLUTTER_BACKEND"
          "wayland"
        ]
        [
          "OZONE_PLATFORM"
          "wayland"
        ]
        [
          "ELECTRON_OZONE_PLATFORM_HINT"
          "wayland"
        ]
        [
          "SDL_VIDEODRIVER"
          "wayland"
        ]
      ];

      config = [
        (args [
          {
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
              # Gradients are a table of colours plus an angle, replacing the old
              # "$a $b $c 45deg" string.
              col = {
                active_border = {
                  colors = [
                    (rgba c.base0D)
                    (rgba c.base0E)
                    (rgba c.base0C)
                    (rgba c.base0D)
                  ];
                  angle = 45;
                };
                inactive_border = {
                  colors = [
                    (rgba c.base02)
                    (rgba c.base03)
                  ];
                  angle = 45;
                };
              };
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

            animations.enabled = true;
            dwindle.preserve_split = true;

            binds = {
              workspace_back_and_forth = true;
              allow_workspace_cycles = true;
              pass_mouse_when_bound = false;
            };

            misc = {
              disable_hyprland_logo = true;
              disable_splash_rendering = true;
              initial_workspace_tracking = 1;
            };
          }
        ])
      ];

      # Beziers are curves now: control points as a list of pairs instead of the
      # old "name, x1, y1, x2, y2" string.
      curve = map args [
        [
          "md3_standard"
          {
            type = "bezier";
            points = [
              [
                0.2
                0
              ]
              [
                0
                1
              ]
            ];
          }
        ]
        [
          "md3_decel"
          {
            type = "bezier";
            points = [
              [
                0.05
                0.7
              ]
              [
                0.1
                1
              ]
            ];
          }
        ]
        [
          "md3_accel"
          {
            type = "bezier";
            points = [
              [
                0.3
                0
              ]
              [
                0.8
                0.15
              ]
            ];
          }
        ]
        [
          "overshot"
          {
            type = "bezier";
            points = [
              [
                0.05
                0.9
              ]
              [
                0.1
                1.1
              ]
            ];
          }
        ]
        [
          "smooth"
          {
            type = "bezier";
            points = [
              [
                0.25
                0.1
              ]
              [
                0.25
                1
              ]
            ];
          }
        ]
        [
          "snappy"
          {
            type = "bezier";
            points = [
              [
                0.4
                0
              ]
              [
                0.2
                1
              ]
            ];
          }
        ]
        [
          "expo"
          {
            type = "bezier";
            points = [
              [
                0.87
                0
              ]
              [
                0.13
                1
              ]
            ];
          }
        ]
        # borderangle references `linear`; define it rather than relying on the
        # built-in defaults being present.
        [
          "linear"
          {
            type = "bezier";
            points = [
              [
                0
                0
              ]
              [
                1
                1
              ]
            ];
          }
        ]
      ];

      # "name, enabled, speed, curve, style" becomes a keyed table.
      animation = map (a: args [ ({ enabled = true; } // a) ]) [
        {
          leaf = "windowsIn";
          speed = 4;
          bezier = "md3_decel";
          style = "popin 60%";
        }
        {
          leaf = "windowsOut";
          speed = 3;
          bezier = "md3_accel";
          style = "popin 60%";
        }
        {
          leaf = "windowsMove";
          speed = 4;
          bezier = "md3_standard";
          style = "slide";
        }
        {
          leaf = "fadeIn";
          speed = 3;
          bezier = "md3_decel";
        }
        {
          leaf = "fadeOut";
          speed = 2;
          bezier = "md3_accel";
        }
        {
          leaf = "fadeSwitch";
          speed = 3;
          bezier = "md3_standard";
        }
        {
          leaf = "fadeShadow";
          speed = 3;
          bezier = "md3_standard";
        }
        {
          leaf = "fadeDim";
          speed = 4;
          bezier = "md3_standard";
        }
        {
          leaf = "fadeLayers";
          speed = 3;
          bezier = "md3_decel";
        }
        {
          leaf = "border";
          speed = 10;
          bezier = "md3_standard";
        }
        {
          leaf = "borderangle";
          speed = 100;
          bezier = "linear";
          style = "loop";
        }
        {
          leaf = "workspaces";
          speed = 5;
          bezier = "md3_decel";
          style = "slide";
        }
        {
          leaf = "specialWorkspace";
          speed = 4;
          bezier = "md3_decel";
          style = "slidefadevert -50%";
        }
        {
          leaf = "layers";
          speed = 3;
          bezier = "md3_decel";
          style = "popin 80%";
        }
      ];

      # Rules move from hyprlang blocks to hl.window_rule/hl.layer_rule tables;
      # match keys that were `match:class` are now nested under `match`.
      window_rule = map (r: args [ r ]) [
        {
          name = "wr-float-nm-editor";
          match.title = "^(nm-connection-editor)$";
          float = true;
        }
        {
          name = "wr-float-qalculate";
          match.title = "^(qalculate-gtk)$";
          float = true;
        }
        {
          # Applies to every window; class is matched as a regex.
          name = "wr-idleinhibit";
          match.class = ".*";
          idle_inhibit = "fullscreen";
        }
        {
          name = "wr-pip";
          match.title = "^(Picture-in-Picture)$";
          float = true;
          pin = true;
          move = "69.5% 4%";
          opacity = "1.0 override";
        }
        {
          name = "wr-float-pavucontrol";
          match.class = "^(.*org.pulseaudio.pavucontrol.*)$";
          float = true;
          size = "700 600";
          center = true;
          pin = true;
        }
        {
          name = "wr-float-blueman";
          match.class = "^(blueman-manager)$";
          float = true;
          size = "800 600";
          center = true;
        }
        {
          name = "wr-float-missioncenter";
          match.class = "^(io.missioncenter.MissionCenter)$";
          float = true;
          pin = true;
          center = true;
          size = "900 600";
        }
        {
          name = "wr-float-calculator";
          match.class = "^(org.gnome.Calculator)$";
          float = true;
          size = "700 600";
          center = true;
        }
        {
          name = "wr-float-share-picker";
          match.class = "^(hyprland-share-picker)$";
          float = true;
          pin = true;
          center = true;
          size = "600 400";
        }
        {
          name = "wr-float-dotfiles";
          match.class = "^(dotfiles-floating)$";
          float = true;
          size = "1000 700";
          center = true;
        }
      ];

      layer_rule = [
        (args [
          {
            name = "lr-noanim-selection";
            match.namespace = "selection";
            no_anim = true;
          }
        ])
      ];
    };

    extraConfig = ''
      -----------------------
      ---- KEYBINDINGS ----
      -----------------------

      ${concatStringsSep "\n" binds}
    '';
  };
}
