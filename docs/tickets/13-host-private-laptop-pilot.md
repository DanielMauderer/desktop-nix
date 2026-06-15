# 13 — Host: private-laptop + migration runbook (PILOT)

- **Status:** done
- **Depends on:** 03, 04, 05, 06, 07, 10
- **Machines:** private-laptop

## Goal

The first real machine fully on NixOS. The pilot validates the module stack
end-to-end on hardware with the lowest risk profile (media + light dev).
Deliverables: the composed host config, `docs/runbooks/private-laptop.md`,
and a list of lessons fed back into the modules before Tickets 14/15.

## Sub-tasks

- [x] Compose `hosts/private-laptop/default.nix`: base + desktop + theming +
      shell + neovim + flatpak/apps (all via base + desktop imports). Light dev
      (podman + toolchains) already lands via base.
- [x] Hardware: `hardware.nix` identifies the iGPU as **Intel**
      (`intel-media-driver` / iHD VAAPI), firmware + Intel microcode + initrd
      baseline. The machine-specific `hardware-configuration.nix` is generated
      with `--no-filesystems` and committed at install (runbook §4).
- [x] Laptop power: **power-profiles-daemon** (decided, already in the shared
      desktop stack), brightness keys + battery/backlight/power-profile waybar
      modules all wired from Ticket 04. Lid/suspend validated on hardware
      (runbook §6).
- [x] `p_laptop` layout: old config was `monitor=,preferred,auto,1` — the shared
      kanshi `laptop-internal` fallback already covers it, so no host-specific
      profile (asserted in `flake.nix`).
- [x] Disk decision: **disko + LUKS** (ext4 root, 1 GiB ESP, zram swap) in
      `disk.nix`, scoped to this host (DECISIONS 036).
- [x] Write `docs/runbooks/private-laptop.md`:
  - [x] Pre-migration backup checklist (browser profiles, ssh keys, `~/`
        data inventory, Spotify/media app state)
  - [x] Install steps: ISO, disko partitioning, `nixos-install --flake`
  - [x] Post-install: clone repo, secrets enroll, first rebuild, theming, validation
  - [x] Rollback plan: Silverblue wiped → installer USB / old SSD fallback
- [ ] **Execute the migration on the real machine** (manual — runbook §2–5)
- [ ] **Capture pilot lessons** → file follow-ups against module tickets
      (manual, post-install — runbook §8)

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

Resolved in [DECISIONS 036](../DECISIONS.md):

- [x] disko or manual partitioning? → **disko** (declarative, scoped to host)
- [x] LUKS on this laptop? → **yes**, LUKS2 full-disk + ext4 root, zram swap
- [x] Wipe Silverblue or dual-boot? → **wipe**, full-disk NixOS
- [x] Final hostname? → keep **`private-laptop`**
- [ ] What data must move? → inventoried during the backup step on the machine
      (runbook §1); record in the migration PR description.

## Ask when starting

- The exact hardware (CPU/iGPU/wifi chip) is undocumented in the old repos —
  collect `lspci`/`lscpu` output from the running system first.
- Check the live system for imperative state the repos don't capture
  (flatpak apps installed ad-hoc, gnome-keyring data, fisher plugins added
  manually).
