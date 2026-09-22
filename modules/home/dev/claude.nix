# Linked as individual files into ~/.claude, never the whole directory, so live
# state (settings.local.json, projects/, history) stays writable and untracked.
{ lib, ... }:
let
  claude = ./claude;
in
{
  home.file = {
    ".claude/settings.json".source = "${claude}/settings.json";
    ".claude/CLAUDE.md".source = "${claude}/CLAUDE.md";
  };

  # Never let home-manager manage settings.local.json — machine-local live state.
  home.file.".claude/settings.local.json".enable = lib.mkForce false;
}
