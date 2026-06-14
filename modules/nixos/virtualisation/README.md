# virtualisation (Ticket 09)

libvirt + qemu/KVM with the virt-manager GUI and virt-viewer console, enabled
on every host (DECISIONS 028). Built for Win11-class guests: an emulated TPM 2.0
via `swtpm`. UEFI firmware needs no wiring — current nixpkgs ships QEMU's OVMF
images (including the Secure-Boot variant) by default.

`maudi` is in the `libvirtd` group, so `virsh -c qemu:///system` and
virt-manager's system connection work without a password. The libvirt
`default` NAT network (`virbr0`, `192.168.122.0/24`) is defined and autostarted
by the `libvirt-default-network.service` oneshot.

## Migrating existing VMs from the Silverblue / maudiblue installs

This is the runbook referenced by Tickets 14 (work-laptop) and 15 (desktop).
libvirt's on-disk format is portable, so a migration is just: copy the qcow2
disk(s), copy the domain XML, fix the paths, redefine.

On the **old** Silverblue machine (per VM, replace `win11` with the domain
name from `virsh list --all`):

```bash
# 1. Disk image(s) — usually under /var/lib/libvirt/images
virsh domblklist win11            # list the qcow2 paths the domain uses
sudo cp /var/lib/libvirt/images/win11.qcow2 /run/media/usb/

# 2. Domain definition (inactive XML, not the live one)
virsh dumpxml win11 > win11.xml
cp win11.xml /run/media/usb/

# Optional NVRAM (UEFI varstore) if the guest is UEFI/Secure-Boot:
sudo cp /var/lib/libvirt/qemu/nvram/win11_VARS.fd /run/media/usb/
```

On the **new** NixOS machine:

```bash
# 1. Drop the disk back under the images pool
sudo cp /run/media/usb/win11.qcow2 /var/lib/libvirt/images/
sudo cp /run/media/usb/win11_VARS.fd /var/lib/libvirt/qemu/nvram/   # if UEFI

# 2. Fix store paths in the XML before defining it. The old <loader>/<nvram>
#    point at Fedora's edk2 firmware; on NixOS they live in the Nix store.
#    virt-manager will also offer to repair these on first open, but doing it
#    up front avoids a define error. Easiest: delete the <loader>/<nvram>/
#    <emulator> lines and let libvirt pick its defaults (OVMF ships by default),
#    then re-enable UEFI + TPM in virt-manager's hardware view.

# 3. Define (do NOT use --validate against the old emulator path) and start
virsh define win11.xml
virsh start win11
virt-manager   # or: virt-viewer win11
```

Notes:

- `default` network names match (`virbr0`), so guests on the default NAT keep
  working without XML edits.
- For a clean cutover prefer copying with the guest **shut down** so the qcow2
  is consistent; live-migrating disks is out of scope here.
- Large images: `rsync --sparse` or `qemu-img convert -O qcow2` (re-sparsify)
  beats a plain `cp` for multi-hundred-GB disks.
