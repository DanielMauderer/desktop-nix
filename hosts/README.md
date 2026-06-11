# hosts/

One directory per machine. Convention (established in Ticket 01):

```
hosts/<name>/
├── default.nix    # host entry point: imports modules, sets host-specific options
└── hardware/      # hardware-configuration.nix, disk layout (disko?), GPU specifics
```

| Host             | Notes                                                              |
|------------------|--------------------------------------------------------------------|
| `private-laptop` | Pilot machine — migrates first (Ticket 13)                         |
| `work-laptop`    | Dev-heavy, wireguard/secrets, migrates second (Ticket 14)          |
| `desktop`        | AMD GPU, gaming + CachyOS kernel, migrates last (Ticket 15)        |

Host-specific Hyprland monitor/workspace layouts (formerly `hypr/conf/monitors/`
`w_laptop*.conf`, `p_laptop.conf`, `default.conf` in MyLinux) are configured here
per host instead of being cycled at runtime by `monitor-hotplug.sh`.
