# 15 — Host: desktop + migration runbook

- **Status:** open
- **Depends on:** 08, 09, 11, 13
- **Machines:** desktop

## Goal

The gaming + dev desktop on NixOS with the CachyOS kernel — the last
migration. The gaming stack (Ticket 11) gets its real-hardware validation
here.

## Sub-tasks

- [ ] Compose `hosts/desktop/default.nix`: base + desktop + theming + shell +
      neovim + dev (08) + libvirt (09) + **gaming (11)**; waydroid per
      Ticket 16's outcome
- [ ] Hardware: AMD dGPU model confirmed, `hardware-configuration.nix`,
      32-bit graphics, monitors `DP-3@2560x1440@144` + `DP-2@1920x1080@60`
      (the old `default.conf` layout) with workspace pinning
- [ ] Disk plan: where does the Steam library live (separate data disk
      mounted declaratively? keep the existing library partition to avoid
      re-downloading)
- [ ] Write `docs/runbooks/desktop.md`: backup (save games not in cloud,
      Steam library strategy, VM images from Ticket 09), install, validation
      checklist, rollback
- [ ] Execute the migration
- [ ] Performance sanity pass vs Silverblue notes (same games, subjective +
      MangoHud numbers) — the point of the CachyOS kernel is measurable

## Testing

- [ ] Baseline: flake check, linters, all host builds, CI green (cachyos
      kernel from chaotic cache — no local kernel build)
- [ ] `nixosTest` accumulation incl. gaming module checks (cachyos kernel
      boots in VM, scx active, gamemoded responds)
- [ ] Acceptance = runbook hardware checklist: `uname -r` cachyos, scx
      scheduler running, `vulkaninfo` RADV, both monitors at correct
      refresh rates, Steam library found without re-download, a Proton game
      and a native game launch, gamemode toggles during play, MangoHud
      overlay, VMs boot, dev devshells work
- [ ] MangoHud comparison numbers recorded (before/after migration if
      possible) in the runbook

## Open questions

- [ ] Steam library: existing partition kept and mounted, or fresh
      re-download? Filesystem of that partition compatible?
- [ ] Dual-boot anything (Windows for anticheat titles?) — affects bootloader
      and disk layout
- [ ] Save-game inventory: which games have non-cloud saves to back up?

## Ask when starting

- Exact AMD GPU model + monitor EDIDs from the live system before writing
  hardware config (Ticket 11 also asks for this — collect once).
- The old desktop monitor config is `default.conf` in MyLinux, not named like
  the laptop ones — confirm DP-3/DP-2 assignment is still accurate.
