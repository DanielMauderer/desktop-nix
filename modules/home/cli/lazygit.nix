# lazygit — ported from MyLinux lazygit/config.yml. The config is large and
# hand-tuned (theme, the full keybinding set, custom commands, delta pager), so
# it is vendored verbatim rather than re-expressed as a Nix attrset — the same
# raw-file idiom used for the rofi/waybar/wlogout assets.
#
# We install the package directly and drop the config in via xdg.configFile,
# deliberately *not* using `programs.lazygit`: that module unconditionally
# defines `home.file.<configHome>/lazygit/config.yml.source` (even with empty
# `settings`), which collides with our vendored file at equal priority. The `lg`
# alias is provided by fish.nix; the delta pager by ../cli/default.nix. The
# gh-based custom PR commands stay dormant until Ticket 08; `editPreset: nvim`
# is harmless until Ticket 07.
{ pkgs, ... }:
{
  home.packages = [ pkgs.lazygit ];

  xdg.configFile."lazygit/config.yml".source = ./config.yml;
}
