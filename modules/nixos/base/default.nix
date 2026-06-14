# Base system module — imported by every host.
# Everything machines share: boot, locale, user, networking, audio, nix
# settings, a minimal CLI set, fonts and the auto-update strategy.
# See docs/tickets/03-base-system-module.md.
#
# ../dev (Ticket 08) is pulled in here so the system-level dev pieces (podman)
# land on every host, matching how home.nix wires the dev home module.
# ../virtualisation (Ticket 09, DECISIONS 028) lands libvirt/KVM on every host
# too — maudiblue enabled libvirtd globally and all three machines keep it.
_: {
  imports = [
    ../dev
    ../virtualisation
    ./audio.nix
    ./boot.nix
    ./fonts.nix
    ./home.nix
    ./locale.nix
    ./networking.nix
    ./nix.nix
    ./packages.nix
    ./updates.nix
    ./users.nix
  ];
}
