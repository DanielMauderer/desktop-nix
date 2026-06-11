# private-laptop

**Pilot machine — migrates to NixOS first** ([Ticket 13](../../docs/tickets/13-host-private-laptop-pilot.md)).

- Role: media consumption + some development
- GPU: Intel/AMD iGPU (identify exact model during Ticket 13)
- Modules: base, hyprland desktop, theming, shell, neovim, flatpak/media apps,
  laptop power management
- Runbook: `docs/runbooks/private-laptop.md` (written as part of Ticket 13)

`hardware/` will hold `hardware-configuration.nix` and the disk layout once the
machine is installed.
