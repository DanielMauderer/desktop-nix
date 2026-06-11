#!/bin/bash
set -euo pipefail

# Only run in remote cloud environments
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

NIX_BIN=/nix/var/nix/profiles/default/bin

# Put nix on PATH for the session
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$NIX_BIN:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

# Validate nix is usable
"$NIX_BIN/nix" --version
