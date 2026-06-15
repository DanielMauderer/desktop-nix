# 11 — Gaming & CachyOS kernel

- **Status:** done
- **Depends on:** 03 (04 for the gamemode keybind wiring)
- **Machines:** desktop

## Goal

`modules/nixos/gaming`, enabled only on the desktop host: CachyOS kernel via
chaotic-cx/nyx, sched-ext scheduler, Steam + gamemode + gamescope, and AMD
GPU support. **Net-new functionality** — the old Silverblue image had no
gaming or GPU config at all, so there is nothing to port; this is built from
scratch against current NixOS gaming best practice.

## Sub-tasks

- [x] chaotic binary cache so the kernel is never compiled locally. The
      `chaotic-cx/nyx` input + `chaotic.nixosModules.default` were already wired
      on the desktop host (Ticket 01); chaotic's module already adds its cache
      (`https://nyx-cache.chaotic.cx/` + trusted key) to the system's
      `nix.settings`. Added the same substituter/key to **CI**
      (`.github/workflows/ci.yml`, both jobs) so the kernel is substituted there
      too (Ticket 02).
- [x] `boot.kernelPackages = pkgs.linuxPackages_cachyos` (desktop only) —
      `modules/nixos/gaming/kernel.nix`.
- [x] sched-ext: `services.scx.enable` with `scheduler = "scx_lavd"`.
- [x] Steam: `programs.steam.enable`, `remotePlay.openFirewall`,
      `gamescopeSession.enable`, declarative Proton-GE via
      `extraCompatPackages = [ proton-ge-bin ]` — `gaming/steam.nix`.
- [x] `programs.gamemode.enable` (feralinteractive). The cosmetic
      `hypr-gamemode.sh` toggle was **dropped** (unused; see resolution below).
- [x] AMD GPU: mesa/RADV (NixOS default), `hardware.graphics.enable32Bit`,
      VAAPI (via mesa); GPU tooling: **LACT** (`services.lact.enable`) —
      `gaming/gpu.nix`.
- [x] MangoHud as HM package + config, set desktop-only via
      `home-manager.users.maudi.programs.mangohud` in `gaming/gpu.nix`.
- [x] Kernel-update cadence documented in DECISIONS 034 (chaotic moves fast;
      `nixos-rebuild --rollback` / pin the chaotic input if a kernel breaks).

## Testing

- [x] Baseline: flake check, linters, all host builds, CI green — CI pulls the
      cachyos kernel from the chaotic cache (substituter configured), not built.
- [x] `test-gaming` nixosTest (`flake.nix`): boots the desktop host on the
      cachyos kernel (`uname -r` contains `cachyos`), `scx.service` active and
      running `scx_lavd`, steam/gamescope/gamemoderun installed,
      `/run/opengl-driver-32` present, LACT + MangoHud installed.
- [x] Eval-level desktop assertions (`host-assertions-desktop`): CachyOS kernel
      selected, scx_lavd, steam + 32-bit + gamemode, MangoHud in home. Laptops
      carry a boundary guard (scx/steam/32-bit all disabled).
- [ ] Manual on hardware (Ticket 15): `vulkaninfo` shows RADV, a real game
      launches via Proton-GE, gamemode activates (`gamemoded -s` during play),
      MangoHud overlay renders, no scheduler/stutter regressions vs Silverblue.

## Open questions (resolved — DECISIONS 034)

- [x] scx scheduler → **`scx_lavd`** (latency-oriented, gaming).
- [x] gamemode + scx → keep `programs.gamemode` (cheap; complements scx). The
      cosmetic Hyprland toggle is gone, so there is no overlap to worry about.
- [x] CachyOS kernel on laptops → **desktop only** (laptops are battery-first
      and one is integrated Intel).
- [x] Proton-GE → **declarative** (`extraCompatPackages`), no protonup-qt.
- [x] GPU overclock/fan tooling → **LACT**.

## Ask when starting (resolved)

- The old `gamemode.sh` cosmetic toggle: **dropped entirely** — the user never
  used it. Only feralinteractive `programs.gamemode` is configured (no keybind).
- AMD GPU model: mesa/RADV + 32-bit Vulkan are RDNA-generation-agnostic, so no
  model-specific wiring is needed; confirm the exact card only for manual
  on-hardware checks in Ticket 15.
