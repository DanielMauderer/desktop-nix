# Device firmware (UEFI/BIOS, SSD, dock, peripherals) via fwupd/LVFS. Separate
# mechanism from `hardware.enableRedistributableFirmware` + CPU microcode in the
# per-host `hardware.nix`, which are kernel-loaded blobs, not flashed ones.
#
# Applied manually — `fwupdmgr refresh && fwupdmgr get-updates && fwupdmgr
# update` — not by `system.autoUpgrade`: a flashed capsule cannot be rolled back
# by picking an older boot generation. The daemon's timer only refreshes LVFS
# metadata, it never flashes on its own.
_: {
  services.fwupd.enable = true;
}
