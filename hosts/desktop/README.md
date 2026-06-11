# desktop

Migrates last ([Ticket 15](../../docs/tickets/15-host-desktop.md)).

- Role: gaming + development
- GPU: **AMD dGPU** (mesa/RADV)
- Kernel: **CachyOS** via chaotic-cx/nyx (`linuxPackages_cachyos`) + sched-ext
  `scx` scheduler — see [Ticket 11](../../docs/tickets/11-gaming-and-cachyos-kernel.md)
- Modules: base, hyprland desktop, theming, shell, neovim, dev environment,
  gaming (steam, gamemode, gamescope), libvirt/KVM
- Monitor layout: DP-3@2560x1440@144 + DP-2@1920x1080@60 (formerly
  `default.conf` in MyLinux)
- Runbook: `docs/runbooks/desktop.md` (written as part of Ticket 15)

`hardware/` will hold `hardware-configuration.nix` and the disk layout once the
machine is installed.
