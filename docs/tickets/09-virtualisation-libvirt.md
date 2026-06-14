# 09 — Virtualisation: libvirt/KVM

- **Status:** done
- **Depends on:** 03
- **Machines:** all (desktop, work-laptop, private-laptop) — DECISIONS 028

## Goal

Parity with maudiblue's virtualisation layer: libvirt + qemu-kvm with the
virt-manager GUI and virt-viewer, as an opt-in NixOS module enabled per host.

## Sub-tasks

- [x] `modules/nixos/virtualisation`: `virtualisation.libvirtd.enable`, qemu
      with KVM + emulated TPM (swtpm) for Win11-class VMs. UEFI/OVMF needs no
      wiring — nixpkgs ships QEMU's OVMF images (incl. Secure Boot) by default
      and removed the old `qemu.ovmf` option.
- [x] `programs.virt-manager.enable`, virt-viewer package
- [x] User in `libvirtd` group; default NAT network defined + autostarted via a
      `libvirt-default-network.service` oneshot
- [x] Polkit interplay: handled by Ticket 04's hyprpolkitagent; libvirtd-group
      membership means `qemu:///system` needs no password at all
- [x] Enablement: all three hosts (DECISIONS 028) → imported from
      `modules/nixos/base` rather than per-host flags
- [x] Existing VM migration documented in
      `modules/nixos/virtualisation/README.md` (feeds Tickets 14/15)

## Testing

- [x] Baseline: flake check, linters, all host builds, CI green
- [x] `nixosTest` (`test-virtualisation`): libvirtd active, `su maudi -c 'virsh
      -c qemu:///system list'` succeeds (group membership effective), default
      network defined + autostart
- [ ] `nixosTest` (nested-virt): define and start a minimal guest — **manual**,
      runner lacks nested KVM
- [ ] Manual on hardware: virt-manager opens, existing VM imported and boots,
      virt-viewer connects — **manual** (deferred to Tickets 14/15 runbooks)

## Open questions

- [x] Which hosts? **All three** (DECISIONS 028) — user chose to match
      maudiblue's global `libvirtd` rather than the desktop+work-laptop default.
- [x] Existing VMs worth migrating? The migration path is documented either way
      (`modules/nixos/virtualisation/README.md`); actual image moves happen in
      the Ticket 14/15 host runbooks.
- [x] Anything else using virtualisation? waydroid (Ticket 16) coexists with KVM;
      no special-networking VMs surfaced — the default NAT network covers the
      known cases.

## Ask when starting

- maudiblue enabled `libvirtd.service` globally on every machine including
  laptops — on NixOS this becomes per-host. **Confirmed:** keep it on all three
  (DECISIONS 028), so the module is wired in `base`.
