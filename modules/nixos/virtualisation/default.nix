# System-level virtualisation (Ticket 09) — libvirt/KVM + virt-manager.
# Imported by modules/nixos/base so it lands on every host (DECISIONS 028 keeps
# all three machines, matching maudiblue's global libvirtd). See ./README.md for
# the VM migration runbook that feeds Tickets 14/15.
_: {
  imports = [ ./libvirt.nix ];
}
