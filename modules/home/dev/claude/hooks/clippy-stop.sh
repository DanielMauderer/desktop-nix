#!/usr/bin/env bash
# Claude Code Stop hook: when Claude finishes inside a Cargo workspace, run
# pedantic clippy (the gate most likely to fail CI). If it reports anything,
# block the stop and hand the output back to Claude so it fixes the warnings
# before the turn ends. Bounded to a few attempts per session so an unfixable
# lint can't loop forever. Receives the Stop-hook JSON on stdin.
#
# cargo + clippy are provided by modules/home/dev (Nix home.packages), on PATH.

input=$(cat)

# Only act inside a Cargo workspace; otherwise let the stop proceed untouched.
[ -f Cargo.toml ] || { printf '{}'; exit 0; }

session=$(printf '%s' "$input" | python3 -c \
	'import sys, json; print(json.load(sys.stdin).get("session_id", "default"))' \
	2>/dev/null)

# Bound retries per session to avoid fix-loops on lints Claude can't resolve.
counter="/tmp/claude-clippy-stop-${session:-default}.count"
attempts=$(cat "$counter" 2>/dev/null || echo 0)

out=$(cargo clippy --workspace --all-targets -- -W clippy::pedantic 2>&1)
status=$?

# no_std targets (e.g. embedded) can't build the per-target test harness, so
# `--all-targets` fails with E0463 "can't find crate for `test`". That's an
# environment limitation, not a lint — fall back to checking just the binaries.
if [ "$status" -ne 0 ] && printf '%s' "$out" | grep -q "can't find crate for \`test\`"; then
	out=$(cargo clippy --workspace --bins -- -W clippy::pedantic 2>&1)
	status=$?
fi

if [ "$status" -eq 0 ]; then
	rm -f "$counter"
	printf '{}'
	exit 0
fi

if [ "${attempts:-0}" -ge 3 ]; then
	rm -f "$counter"
	printf '{"systemMessage":"clippy still reports warnings after 3 attempts; leaving the turn as-is"}'
	exit 0
fi
echo $((attempts + 1)) >"$counter"

# Block the stop and feed clippy's output back to Claude.
printf '%s' "$out" | python3 -c '
import sys, json
out = sys.stdin.read()
print(json.dumps({
    "decision": "block",
    "reason": "Pedantic clippy reported issues — fix them before finishing:\n\n" + out,
}))
'
exit 0
