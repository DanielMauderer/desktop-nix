# Base system module — imported by every desktop/workstation host.
# = the shared `../core` baseline (boot, locale, networking, nix, secrets,
# updates, hardening, audit, packages, user) PLUS the desktop/workstation extras
# that the headless home-server deliberately does NOT want.
# See docs/tickets/03-base-system-module.md and DECISIONS 049 for the core split.
#
# ../apps.nix (Ticket 10, DECISIONS 029-033) lands GUI apps (Spotify, Zen Browser,
# mpv, imv) plus the allowUnfreePredicate allowlist.
# ../dev (Ticket 08) lands the system-level dev pieces (podman) on every
# workstation, matching how home.nix wires the dev home module.
# ../virtualisation (Ticket 09, DECISIONS 028) lands libvirt/KVM — maudiblue
# enabled libvirtd globally and all three desktop machines keep it.
# ./audio.nix (PipeWire), ./fonts.nix and ./home.nix (the cli/neovim/dev home
# modules) round out the workstation baseline.
_: {
  imports = [
    ../core
    ../apps.nix
    ../dev
    ../virtualisation
    ./audio.nix
    ./fonts.nix
    ./home.nix
  ];
}
