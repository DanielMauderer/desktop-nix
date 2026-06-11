# 16 — Waydroid

- **Status:** open
- **Depends on:** 03
- **Machines:** TBD — possibly none (drop candidate)

## Goal

Decide whether the Android container is still wanted, and if yes, achieve
parity with maudiblue's layered `waydroid` package via
`virtualisation.waydroid` on the hosts that need it.

## Sub-tasks

- [ ] **Decide first: is waydroid actually used?** It was layered into the
      image but nothing else in the old config references it. If unused →
      mark dropped in INVENTORY.md, close this ticket.
- [ ] If kept: `virtualisation.waydroid.enable` in an opt-in module
- [ ] Verify Wayland integration under Hyprland (window rules for the
      waydroid windows, multi-window mode?)
- [ ] Document the imperative parts that stay imperative: `waydroid init`
      image download, optional GAPPS image, Android data in `~/.local/share/waydroid`
- [ ] Pick hosts

## Testing

- [ ] Baseline: flake check, linters, all host builds, CI green
- [ ] `nixosTest`: waydroid-container service starts (full Android boot needs
      hardware/KVM — mark manual)
- [ ] Manual on hardware: `waydroid session start`, an app renders under
      Hyprland, input works

## Open questions

- [ ] Used at all? Which apps? (If it's one app, is there a web/native
      alternative that kills this ticket?)
- [ ] GAPPS image needed (Google Play) — licensing/device-registration hassle
      acceptable?

## Ask when starting

- Confirm usage before any implementation — this is the most likely
  "consciously dropped" row in INVENTORY.md.
