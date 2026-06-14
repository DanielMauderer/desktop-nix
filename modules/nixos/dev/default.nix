# System-level dev environment (Ticket 08) — containers.
# Imported by modules/nixos/base so it lands on every host (the dev environment
# is wired in base like the cli/neovim home modules). Language toolchains and
# the Claude config are per-user and live in modules/home/dev.
_: {
  imports = [ ./podman.nix ];
}
