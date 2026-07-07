# Logout / power menu. stylix has no wlogout target, so the colours are
# prepended from the stylix palette here.
{ config, ... }:
let
  c = config.lib.stylix.colors.withHashtag;
  colorCss = ''
    @define-color base ${c.base00};
    @define-color mauve ${c.base0D};
    @define-color text ${c.base05};
  '';
in
{
  programs.wlogout = {
    enable = true;
    layout = [
      {
        label = "lock";
        action = "swaylock";
        text = "Lock";
        keybind = "l";
      }
      {
        label = "suspend";
        action = "systemctl suspend";
        text = "Suspend";
        keybind = "u";
      }
      {
        label = "reboot";
        action = "systemctl reboot";
        text = "Reboot";
        keybind = "r";
      }
      {
        label = "shutdown";
        action = "systemctl poweroff";
        text = "Shutdown";
        keybind = "s";
      }
      {
        label = "logout";
        action = "loginctl terminate-user $USER";
        text = "Logout";
        keybind = "e";
      }
    ];
    style = colorCss + builtins.readFile ./wlogout-style.css;
  };
}
