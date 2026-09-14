# desktop

Gaming + development workstation (at home). Install guide: [INSTALL.md](INSTALL.md).

- **Role:** gaming + dev
- **GPU/CPU:** AMD dGPU (mesa/RADV) + AMD CPU (`kvm-amd`, `amd-ucode`)
- **Kernel:** **CachyOS** (`linuxPackages_cachyos`) + `scx` sched-ext scheduler,
  via chaotic-cx/nyx — desktop only
- **Modules:** `base` + `desktop` + `gaming` (Steam, gamemode, gamescope, AMD
  GPU/LACT, MangoHud) + `waydroid` + `net` (home-server VPN client — `ssh
  home-server` + the NFS share, mounted over the LAN; enrolled per INSTALL.md)
- **Monitoring:** pushes host metrics (60s) and warning-level journal to the
  server's Grafana over `wg0` — one low-priority Alloy process, no inbound port,
  *Workstations — fleet* dashboard at `http://10.100.0.1:3030`. See
  `modules/nixos/net/telemetry.nix`.
- **Disk:** **LUKS2 + ext4** full-disk encryption (passphrase at boot, like the
  laptops); disko GPT + ESP + LUKS root. Steam library is a fresh re-download.
- **Monitors:** kanshi `desktop` profile — `DP-3` (Acer XF272U) 2560x1440@144 @
  0,0 and `DP-2` (Acer G276HL) 1920x1080@60 @ 2560,0. With the Samsung QBQ90S on
  `DP-1` the `desktop+tv` profile matches instead: same two Acers, plus the TV
  mirroring `DP-3` at 2560x1440 (an `exec` into Hyprland — kanshi can't mirror).
  Workspaces 1-5 are pinned to `DP-3`, 6-10 to `DP-2`; the mirror gets none.

`hardware.nix` carries the AMD enablement (`amdgpu` early KMS, `radeonsi` VAAPI,
zram). `hardware/` holds the generated `hardware-configuration.nix` (added at
install).
