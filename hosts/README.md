# hosts/

One directory per machine:

```
hosts/<name>/
├── default.nix    # entry point: imports modules, sets host-specific options
├── hardware.nix   # GPU/CPU/firmware enablement (hand-written)
├── disk.nix       # disko partition layout (wired in via flake.nix)
├── hardware/      # generated hardware-configuration.nix (added at install)
├── README.md      # what this machine is
└── INSTALL.md     # how to install it
```

| Host             | Role              | Stack                                          |
|------------------|-------------------|------------------------------------------------|
| `private-laptop` | Media + light dev | base + desktop + waydroid                      |
| `work-laptop`    | Heavy dev         | base + desktop (+ wireguard)                   |
| `desktop`        | Gaming + dev      | base + desktop + gaming + waydroid             |
| `home-server`    | Headless services | core + dev + server                            |

Host-specific Hyprland monitor layouts live in each host's `default.nix`
(kanshi profiles), not cycled at runtime.
