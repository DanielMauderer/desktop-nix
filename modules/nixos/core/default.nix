# Core system module — imported by EVERY host (workstations and the home server).
# The genuinely machine-agnostic baseline: boot, locale, networking, nix
# settings, secrets infrastructure, the auto-update strategy, security hardening
# + audit logging, a minimal CLI package set and the primary user.
#
# Split out of the old `base` module (DECISIONS 049) so the headless home-server
# can share these primitives WITHOUT the desktop/workstation extras (GUI apps,
# PipeWire, libvirt, fonts, the cli/neovim/dev home wiring) that now live in
# `../base`. The three desktop hosts get everything by importing `../base`,
# which imports this; the server imports `../core` directly.
_: {
  imports = [
    ./audit.nix
    ./boot.nix
    ./hardening.nix
    ./locale.nix
    ./networking.nix
    ./nix.nix
    ./packages.nix
    ./secrets.nix
    ./updates.nix
    ./users.nix
  ];
}
