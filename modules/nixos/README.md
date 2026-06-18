# modules/nixos/

System-level (NixOS) modules. Each group has its own README.

| Group            | What it configures                                              |
|------------------|----------------------------------------------------------------|
| `core`           | Machine-agnostic baseline: boot, locale, networking, nix, users, secrets, updates, hardening, audit. Imported by every host. |
| `base`           | `core` + workstation extras (GUI apps, audio, libvirt, fonts, home modules). The three desktop hosts. |
| `desktop`        | Hyprland session, greeter, portals, theming; wires the home desktop module. |
| `dev`            | System-side dev: Podman + podman-compose.                      |
| `virtualisation` | libvirt/KVM + virt-manager, OVMF, TPM.                         |
| `gaming`         | CachyOS kernel, `scx`, Steam, gamemode, gamescope, AMD GPU/LACT. Desktop only. |
| `waydroid`       | Android container (opt-in: private-laptop + desktop).         |
| `server`         | home-server services: WireGuard server, SSH-over-VPN, reverse-proxy, ZFS, NFS. |

`apps.nix` (GUI app allowlist) lives directly under `modules/nixos/`.
