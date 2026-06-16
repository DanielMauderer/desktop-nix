# Base system module — imported by every host.
# Everything machines share: boot, locale, user, networking, audio, nix
# settings, a minimal CLI set, fonts and the auto-update strategy.
# See docs/tickets/03-base-system-module.md.
#
# ../apps.nix (Ticket 10, DECISIONS 029-033) lands GUI apps (Spotify, Zen Browser,
# mpv, imv) plus the allowUnfreePredicate allowlist on every host.
# ../dev (Ticket 08) is pulled in here so the system-level dev pieces (podman)
# land on every host, matching how home.nix wires the dev home module.
# ../virtualisation (Ticket 09, DECISIONS 028) lands libvirt/KVM on every host
# too — maudiblue enabled libvirtd globally and all three machines keep it.
_: {
  imports = [
    ../apps.nix
    ../dev
    ../virtualisation
    ./audio.nix
    ./audit.nix
    ./boot.nix
    ./fonts.nix
    ./hardening.nix
    ./home.nix
    ./locale.nix
    ./networking.nix
    ./nix.nix
    ./packages.nix
    ./secrets.nix
    ./updates.nix
    ./users.nix
  ];
}
