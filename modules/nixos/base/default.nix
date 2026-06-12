# Base system module — imported by every host.
# Everything machines share: boot, locale, user, networking, audio, nix
# settings, a minimal CLI set, fonts and the auto-update strategy.
# See docs/tickets/03-base-system-module.md.
_: {
  imports = [
    ./audio.nix
    ./boot.nix
    ./fonts.nix
    ./locale.nix
    ./networking.nix
    ./nix.nix
    ./packages.nix
    ./updates.nix
    ./users.nix
  ];
}
