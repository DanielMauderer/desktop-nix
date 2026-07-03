# net

Cross-host networking — how a machine reaches *other* hosts (the counterpart to
`core/networking.nix`, which is a host's own baseline). Imported explicitly by
the hosts that need it.

| File                     | Configures                                                                                                                                                                 |
|--------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `home-server-client.nix` | `services.homeServerClient`: WireGuard **client** of the home-server (`wg0`, split-tunnel to `10.100.0.0/24`), `known_hosts` pin for `home-server`, and an `x-systemd.automount` NFS mount of the share at `/mnt/home-server`. Gated by `enable` — off until the host is enrolled (per-host private key via sops), so importing it keeps keyless CI green. |

The `serverPublicKey` / `serverHostKey` / `endpoint` options default to
placeholders and are the same for every client, so fill them once here. Per host
you set only `address` (its `/32`) and `nfsHost` (LAN IP for an always-home box,
`10.100.0.1` for a roaming laptop). Server half: `modules/nixos/server/`.
Enrollment steps: `hosts/private-laptop/INSTALL.md`.
