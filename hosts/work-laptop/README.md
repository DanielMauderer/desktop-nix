# work-laptop

Migrates second, after the pilot ([Ticket 14](../../docs/tickets/14-host-work-laptop.md)).

- Role: heavy development
- GPU: Intel/AMD iGPU (identify exact model during Ticket 14)
- Modules: base, hyprland desktop, theming, shell, neovim, full dev environment,
  libvirt/KVM, secrets (wireguard/VPN), laptop power management
- Monitor layouts: docked 1/2-external-monitor setups (formerly
  `w_laptop*.conf` in MyLinux)
- Runbook: `docs/runbooks/work-laptop.md` (written as part of Ticket 14)

`hardware/` will hold `hardware-configuration.nix` and the disk layout once the
machine is installed.
