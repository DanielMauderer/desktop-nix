#!/usr/bin/env bash
# Claude Code status line: "  <dir>    <branch>    <model>".
# Receives session JSON on stdin.

input=$(cat)

read_json() {
	printf '%s' "$input" | python3 -c \
		"import sys, json; d = json.load(sys.stdin); print($1)" 2>/dev/null
}

model=$(read_json 'd.get("model", {}).get("display_name", "")')
cwd=$(read_json 'd.get("workspace", {}).get("current_dir", "")')
[ -z "$cwd" ] && cwd=$(pwd)

dir=$(basename "$cwd")
branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)

out="  $dir"
[ -n "$branch" ] && out="$out    $branch"
[ -n "$model" ] && out="$out    󰚩 $model"

printf '%s' "$out"
