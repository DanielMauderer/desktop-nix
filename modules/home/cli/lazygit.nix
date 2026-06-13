# lazygit — ported from MyLinux lazygit/config.yml. The config is large and
# hand-tuned (theme, the full keybinding set, custom commands, delta pager), so
# it is vendored verbatim rather than re-expressed as a Nix attrset — the same
# raw-file idiom used for the rofi/waybar/wlogout assets.
#
# `programs.lazygit` with empty `settings` installs the package but does not
# write the config file, leaving the field clear for the vendored source below.
# The delta pager is provided via ../cli/default.nix's package list. The
# gh-based custom PR commands stay dormant until Ticket 08; `editPreset: nvim`
# is harmless until Ticket 07.
_: {
  programs.lazygit.enable = true;

  xdg.configFile."lazygit/config.yml".source = ./config.yml;
}
