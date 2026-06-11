# 13 — Host: private-laptop + migration runbook (PILOT)

- **Status:** open
- **Depends on:** 03, 04, 05, 06, 07, 10
- **Machines:** private-laptop

## Goal

The first real machine fully on NixOS. The pilot validates the module stack
end-to-end on hardware with the lowest risk profile (media + light dev).
Deliverables: the composed host config, `docs/runbooks/private-laptop.md`,
and a list of lessons fed back into the modules before Tickets 14/15.

## Sub-tasks

- [ ] Compose `hosts/private-laptop/default.nix`: base + desktop + theming +
      shell + neovim + flatpak/apps (light dev profile from Ticket 08 optional)
- [ ] Hardware: generate `hardware-configuration.nix`, identify the iGPU
      (Intel vs AMD → video driver/VAAPI bits), firmware
- [ ] Laptop power: power-profiles-daemon vs TLP (decide), lid/suspend
      behavior, brightness keys, battery waybar module works
- [ ] `p_laptop` monitor/workspace layout from MyLinux as this host's config
- [ ] Disk decision: disko (declarative partitioning, recommended for
      reproducibility) vs manual; LUKS full-disk encryption yes/no; filesystem
      (ext4 vs btrfs — keep simple unless snapshots wanted)
- [ ] Write `docs/runbooks/private-laptop.md`:
  - [ ] Pre-migration backup checklist (browser profiles, ssh keys, `~/`
        data inventory, Spotify/media app state)
  - [ ] Install steps: ISO, partitioning, `nixos-install --flake`
  - [ ] Post-install: clone repo, first rebuild, theming bootstrap
        (wallpaper into state dir), validation checklist
  - [ ] Rollback plan: keep the Silverblue disk untouched? (USB-boot fallback /
        old SSD on a shelf)
- [ ] Execute the migration on the real machine
- [ ] Capture pilot lessons → file follow-up fixes against the module tickets

## Testing

- [ ] Baseline: flake check, linters, all host builds, CI green
- [ ] Full `nixosTest` for this host config where headless-testable (boots,
      greeter, user session, fish, fonts) — accumulated from Tickets 03–07
- [ ] **Acceptance test = the runbook's hardware validation checklist**, run
      on the machine: wifi, audio, bluetooth, suspend/resume, brightness,
      Hyprland session, waybar, notifications, screenshot, lock, wallpaper
      re-theme, nvim `:checkhealth`, media playback (hw video decode), app
      launches
- [ ] Rollback drill: prove the previous generation boots from the
      bootloader menu after an intentional bad change

## Open questions

- [ ] disko or manual partitioning?
- [ ] LUKS on this laptop? (Recommended for any laptop.)
- [ ] Wipe Silverblue or dual-boot during a transition period?
- [ ] Final hostname (`private-laptop` or something nicer)?
- [ ] What data actually lives on this machine that must move? (Inventory
      during the backup sub-task.)

## Ask when starting

- The exact hardware (CPU/iGPU/wifi chip) is undocumented in the old repos —
  collect `lspci`/`lscpu` output from the running system first.
- Check the live system for imperative state the repos don't capture
  (flatpak apps installed ad-hoc, gnome-keyring data, fisher plugins added
  manually).
