# modules/nixos/

System-level (NixOS) modules shared between hosts. Planned modules and the
tickets that create them:

| Module           | Content                                                       | Ticket |
|------------------|---------------------------------------------------------------|--------|
| `base`           | boot, locale, user, networking, audio, nix settings, CLI, fonts | 03   |
| `desktop`        | Hyprland session, greeter, portals, policykit                 | 04     |
| `dev`            | podman/podman-compose, system-side dev tooling                | 08     |
| `virtualisation` | libvirt/KVM, virt-manager, OVMF/TPM                           | 09     |
| `flatpak`        | flatpak + declarative apps (if kept)                          | 10     |
| `gaming`         | CachyOS kernel, scx, steam, gamemode, gamescope, AMD GPU      | 11     |
| `secrets`        | sops-nix (or agenix) wiring                                   | 12     |
| `waydroid`       | Android container (if kept)                                   | 16     |
