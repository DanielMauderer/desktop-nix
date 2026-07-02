# desktop

Gaming + development workstation (at home). Install guide: [INSTALL.md](INSTALL.md).

- **Role:** gaming + dev
- **GPU/CPU:** AMD dGPU (mesa/RADV) + AMD CPU (`kvm-amd`, `amd-ucode`)
- **Kernel:** **CachyOS** (`linuxPackages_cachyos`) + `scx` sched-ext scheduler,
  via chaotic-cx/nyx — desktop only
- **Modules:** `base` + `desktop` + `gaming` (Steam, gamemode, gamescope, AMD
  GPU/LACT, MangoHud) + `waydroid` + `net` (home-server VPN client — `ssh
  home-server` + the NFS share, mounted over the LAN; enrolled per INSTALL.md)
- **Disk:** **LUKS2 + ext4** full-disk encryption (passphrase at boot, like the
  laptops); disko GPT + ESP + LUKS root. Steam library is a fresh re-download.
- **Monitors:** kanshi `desktop` profile — `DP-3` 2560x1440@144 @ 0,0 and `DP-2`
  1920x1080@60 @ 2560,0.

`hardware.nix` carries the AMD enablement (`amdgpu` early KMS, `radeonsi` VAAPI,
zram). `hardware/` holds the generated `hardware-configuration.nix` (added at
install).
