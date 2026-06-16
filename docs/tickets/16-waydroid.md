# 16 — Waydroid

- **Status:** done
- **Depends on:** 03
- **Machines:** private-laptop, desktop (NOT work-laptop — DECISIONS 040)

## Goal

Decide whether the Android container is still wanted, and if yes, achieve
parity with maudiblue's layered `waydroid` package via
`virtualisation.waydroid` on the hosts that need it.

## Outcome

Kept, but **opt-in per host**: enabled on private-laptop and desktop, dropped
on work-laptop (its security baseline has no place for an Android runtime).
See DECISIONS 040. Implemented as `modules/nixos/waydroid/default.nix`
(imported only by the two personal hosts, the same desktop-only pattern the
gaming stack uses), with Hyprland window rules for the Android toplevels
merged into maudi's home config.

## Sub-tasks

- [x] **Decide first: is waydroid actually used?** Confirmed kept (user
      decision): wanted on the two personal machines. maudiblue layered the
      `waydroid` rpm but nothing else referenced it — no init automation, no
      GAPPS, no window rules — so this is a thin enablement, not a port.
- [x] If kept: `virtualisation.waydroid.enable` in an opt-in module
      (`modules/nixos/waydroid/default.nix`, imported by private-laptop +
      desktop, NOT base, NOT work-laptop).
- [x] Verify Wayland integration under Hyprland: the module contributes
      `windowrule`s that float the `waydroid.*` app windows and the `Waydroid`
      full-UI launcher (multi-window mode) and idle-inhibit while focused; they
      merge with the shared home `windowrule` list.
- [x] Document the imperative parts that stay imperative: `waydroid init`
      image download (+ optional GAPPS via `-s GAPPS`), `waydroid session
      start` / `show-full-ui`, and Android data in `~/.local/share/waydroid` +
      `/var/lib/waydroid` — captured in the module header.
- [x] Pick hosts: private-laptop + desktop.

## Testing

- [x] Baseline: flake check, linters, all host builds, CI green
      (nixfmt/statix/deadnix clean; the three `host-assertions-*` checks build;
      per-host eval confirms `waydroid.enable` true/false/true on
      private-laptop/work-laptop/desktop).
- [x] `nixosTest`: `test-waydroid` asserts the waydroid CLI + the
      `waydroid-container.service` unit are installed and the Hyprland window
      rules rendered. Full Android boot needs hardware/KVM + binder + the
      imperative image download — marked manual.
- [ ] Manual on hardware: `waydroid init`, `waydroid session start`, an app
      renders under Hyprland, input works. (Left to post-migration validation.)

## Open questions

- [x] Used at all? Which apps? → Kept on the two personal machines (user
      decision). No specific app list; vanilla image is sufficient.
- [x] GAPPS image needed (Google Play) → Not wired in. `waydroid init` uses the
      vanilla LineageOS image; GAPPS stays a manual `-s GAPPS` choice if a
      Play-only app ever forces it (DECISIONS 040).

## Ask when starting

- Confirm usage before any implementation — **done**: user confirmed waydroid
  on private-laptop + desktop, dropped on work-laptop.
