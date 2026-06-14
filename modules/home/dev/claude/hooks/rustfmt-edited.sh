#!/usr/bin/env bash
# Claude Code PostToolUse hook: run rustfmt on any .rs file Claude just edited,
# so AI-written Rust matches the same rustfmt conform.nvim uses in the editor.
# Receives the tool-call JSON on stdin; stays silent and never blocks the tool.
#
# rustfmt is now provided by modules/home/dev (Nix home.packages), on PATH for
# every shell — no toolbox indirection.

input=$(cat)

file=$(printf '%s' "$input" | python3 -c \
	'import sys, json; print(json.load(sys.stdin).get("tool_input", {}).get("file_path", ""))' \
	2>/dev/null)

case "$file" in
	*.rs) ;;
	*) exit 0 ;;
esac

[ -f "$file" ] || exit 0
command -v rustfmt >/dev/null 2>&1 && rustfmt "$file" >/dev/null 2>&1

exit 0
