# System-level virtualisation (Ticket 09) — libvirt/KVM + virt-manager.
# Imported by modules/nixos/base so it lands on every workstation (DECISIONS 028
# keeps all of them, matching maudiblue's global libvirtd; the headless
# home-server skips base and with it this module). See ./README.md for the VM
# migration runbook that feeds Tickets 14/15.
_: {
  imports = [ ./libvirt.nix ];
}
