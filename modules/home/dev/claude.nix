# Claude Code configuration (Ticket 08) — ported from MyLinux `claude/`.
#
# Linked as INDIVIDUAL files into ~/.claude, never the whole directory: ~/.claude
# holds live state (settings.local.json, projects/, todos/, history) that must
# stay writable and untracked. Each file below is a read-only store symlink; the
# rest of ~/.claude is left untouched.
#
# The PostToolUse rustfmt hook and the Stop clippy hook find rustfmt/cargo/clippy
# on PATH from modules/home/dev/default.nix (no toolbox indirection anymore).
{ lib, ... }:
let
  claude = ./claude;
in
{
  home.file = {
    ".claude/settings.json".source = "${claude}/settings.json";
    ".claude/CLAUDE.md".source = "${claude}/CLAUDE.md";

    ".claude/statusline.sh" = {
      source = "${claude}/statusline.sh";
      executable = true;
    };

    ".claude/hooks/rustfmt-edited.sh" = {
      source = "${claude}/hooks/rustfmt-edited.sh";
      executable = true;
    };
    ".claude/hooks/clippy-stop.sh" = {
      source = "${claude}/hooks/clippy-stop.sh";
      executable = true;
    };

    ".claude/commands/clippy.md".source = "${claude}/commands/clippy.md";
    ".claude/commands/nextest.md".source = "${claude}/commands/nextest.md";
  };

  # Belt-and-suspenders: never let home-manager manage settings.local.json, even
  # if a future refactor globs the directory. It is machine-local, live state.
  home.file.".claude/settings.local.json".enable = lib.mkForce false;
}
