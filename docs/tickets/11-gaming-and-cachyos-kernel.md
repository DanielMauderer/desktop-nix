# 11 — Gaming & CachyOS kernel

- **Status:** open
- **Depends on:** 03 (04 for the gamemode keybind wiring)
- **Machines:** desktop

## Goal

`modules/nixos/gaming`, enabled only on the desktop host: CachyOS kernel via
chaotic-cx/nyx, sched-ext scheduler, Steam + gamemode + gamescope, and AMD
GPU support. **Net-new functionality** — the old Silverblue image had no
gaming or GPU config at all, so there is nothing to port; this is built from
scratch against current NixOS gaming best practice.

## Sub-tasks

- [ ] Flake input `chaotic-cx/nyx`; configure the chaotic binary cache
      (`https://chaotic-nyx.cachix.org` substituter + trusted key) in nix
      settings so the kernel is never compiled locally (also in CI, per
      Ticket 02)
- [ ] `boot.kernelPackages = pkgs.linuxPackages_cachyos` (desktop only)
- [ ] sched-ext: `services.scx.enable` with scheduler choice (`scx_lavd` is
      the gaming-oriented default; see open questions)
- [ ] Steam: `programs.steam.enable`, remote-play firewall opts,
      protonup/proton-ge handling, gamescope session option
- [ ] `programs.gamemode.enable` + wire the existing SUPER-keybind /
      `gamemode.sh` flag from Ticket 04 to gamemoderun semantics (or drop the
      custom script in favor of plain gamemode — decide)
- [ ] AMD GPU: mesa/RADV (default on NixOS), Vulkan 32-bit
      (`hardware.graphics.enable32Bit` for Steam), VAAPI; GPU
      tooling: LACT or corectrl (decide)
- [ ] MangoHud as HM package + config
- [ ] Document kernel-update cadence implications (chaotic moves fast;
      pinning strategy if a kernel breaks)

## Testing

- [ ] Baseline: flake check, linters, all host builds, CI green —
      **CI must pull the cachyos kernel from the chaotic cache, not build it**
      (assert cache hit / build time)
- [ ] `nixosTest` with the gaming module: VM boots the cachyos kernel
      (`uname -r` contains `cachyos`), scx service active and reports its
      scheduler, gamemoded responds to `gamemoded -s`
- [ ] Desktop toplevel closure builds with steam + 32-bit libs (eval-level
      guard against unfree/32-bit misconfig)
- [ ] Manual on hardware (Ticket 15): `vulkaninfo` shows RADV, a real game
      launches via Proton, gamemode activates (`gamemoded -s` during play),
      MangoHud overlay renders, no scheduler/stutter regressions vs Silverblue

## Open questions

- [ ] Which scx scheduler: `scx_lavd` (latency-oriented, gaming) vs
      `scx_bpfland` vs `scx_rusty`? Benchmark or just pick lavd?
- [ ] gamemode + scx interaction: gamemode's renice/governor tweaks may be
      redundant under scx — keep both?
- [ ] CachyOS kernel on the laptops too (battery vs perf), or desktop only?
      (Current plan: desktop only.)
- [ ] Proton-GE management: declarative (nix) vs protonup-qt (imperative)?
- [ ] GPU overclock/fan tooling wanted (LACT/corectrl) or stock?

## Ask when starting

- The old `gamemode.sh` Hyprland script only toggles a flag file + Hyprland
  decorations — it is *not* feralinteractive gamemode. Decide: merge both
  (hyprland cosmetic toggle triggered by real gamemode hooks) or keep
  separate keybinds.
- Confirm the desktop's exact AMD GPU model (RDNA generation matters for
  mesa/firmware expectations) when starting.
