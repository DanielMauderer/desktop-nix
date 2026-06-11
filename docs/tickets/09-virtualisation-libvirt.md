# 09 — Virtualisation: libvirt/KVM

- **Status:** open
- **Depends on:** 03
- **Machines:** desktop, work-laptop (private-laptop: TBD, probably not)

## Goal

Parity with maudiblue's virtualisation layer: libvirt + qemu-kvm with the
virt-manager GUI and virt-viewer, as an opt-in NixOS module enabled per host.

## Sub-tasks

- [ ] `modules/nixos/virtualisation`: `virtualisation.libvirtd.enable`, qemu
      with KVM, UEFI guests (OVMF) + emulated TPM (swtpm) for Win11-class VMs
- [ ] `programs.virt-manager.enable`, virt-viewer package
- [ ] User in `libvirtd` group; default libvirt network autostart decision
- [ ] Polkit interplay: virt-manager auth works under Hyprland with the agent
      chosen in Ticket 04
- [ ] Per-host enablement flags (`desktop`, `work-laptop`; not the pilot
      unless wanted)
- [ ] Existing VM migration: document how to move qcow2 images + domain XML
      from the Silverblue installs (feeds the runbooks of Tickets 14/15)

## Testing

- [ ] Baseline: flake check, linters, all host builds, CI green
- [ ] `nixosTest`: libvirtd active, `virsh -c qemu:///system list` succeeds
      for the user (group membership effective), default network defined
- [ ] `nixosTest` (nested-virt if runner allows, else mark manual): define and
      start a minimal guest
- [ ] Manual on hardware: virt-manager opens, existing VM imported and boots,
      virt-viewer connects

## Open questions

- [ ] Which hosts? Desktop + work-laptop assumed; does the private laptop
      ever run VMs?
- [ ] Are there existing VMs worth migrating, or start fresh?
- [ ] waydroid (Ticket 16) and KVM coexist fine, but does anything else use
      virtualisation (e.g. work-mandated VMs with special networking)?

## Ask when starting

- maudiblue enabled `libvirtd.service` globally on every machine including
  laptops — on NixOS this becomes per-host; confirm the host list above.
