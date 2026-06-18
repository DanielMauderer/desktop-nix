# desktop

Gaming + development workstation (at home). Install guide: [INSTALL.md](INSTALL.md).

- **Role:** gaming + dev
- **GPU/CPU:** AMD dGPU (mesa/RADV) + AMD CPU (`kvm-amd`, `amd-ucode`)
- **Kernel:** **CachyOS** (`linuxPackages_cachyos`) + `scx` sched-ext scheduler,
  via chaotic-cx/nyx — desktop only
- **Modules:** `base` + `desktop` + `gaming` (Steam, gamemode, gamescope, AMD
  GPU/LACT, MangoHud) + `waydroid`
- **Disk:** plain **ext4, no LUKS** (no passphrase at boot — physical security at
  home); disko GPT + ESP + ext4 root. Steam library is a fresh re-download.
- **Monitors:** kanshi `desktop` profile — `DP-3` 2560x1440@144 @ 0,0 and `DP-2`
  1920x1080@60 @ 2560,0.

`hardware.nix` carries the AMD enablement (`amdgpu` early KMS, `radeonsi` VAAPI,
zram). `hardware/` holds the generated `hardware-configuration.nix` (added at
install).
