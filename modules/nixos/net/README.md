# net

Cross-host networking — how a machine reaches *other* hosts (the counterpart to
`core/networking.nix`, which is a host's own baseline). Imported explicitly by
the hosts that need it.

| File                     | Configures                                                                                                                                                                 |
|--------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `home-server-client.nix` | `services.homeServerClient`: WireGuard **client** of the home-server (`wg0`, split-tunnel to `10.100.0.0/24`), `known_hosts` pin for `home-server`, and an `x-systemd.automount` NFS mount of the share at `/mnt/home-server`. Gated by `enable` — off until the host is enrolled (per-host private key via sops), so importing it keeps keyless CI green. |

| `telemetry.nix` | `services.homeServerTelemetry`: a single **Grafana Alloy** that pushes this host's metrics and warning-level journal into the home-server's stack over `wg0` — `prometheus.exporter.unix` (the node exporter, in-process, no second unit and no listener) scraped every 60s and `remote_write`n to the server's ingest on `:9099`, plus `loki.source.journal` filtered to priority ≤ 4 and pushed to `:3100`. **Push, not scrape**, so an off or sleeping host is an absent series rather than a firing `hs-target-down` in the server's `alerts.nix`; a consequence is that "is it awake" is read off the *Last sample age* panel, not `up`. Opens no inbound port. Labels its series `job="client-node"` / `job="client-journal"` — distinct from the server's own `node`/`systemd-journal`, which is what keeps the two apart in Grafana. Low-priority `Nice`/`CPUWeight`/`IOWeight` and a `MemoryMax`, deliberately no `CPUQuota`. Also `enable`-gated, and useless without `homeServerClient` (asserted in `flake.nix`). |

| `vpn-client.nix` | `services.vpnClient`: a **second** WireGuard tunnel on `wg1` from a provider-issued `wg.conf` — full tunnel by default, `autostart = false`, private key from `secrets/<host>/vpn.yaml` (`vpn-wg-key`). Set `presharedKey = true` when the `wg.conf` has a `PresharedKey` line; the value is read from `vpn-wg-psk` in that same file. Also `enable`-gated. |

The `serverPublicKey` / `serverHostKey` / `endpoint` options default to
placeholders and are the same for every client, so fill them once here. Per host
you set only `address` (its `/32`) and `nfsHost` (LAN IP for an always-home box,
`10.100.0.1` for a roaming laptop). Server half: `modules/nixos/server/`.
Enrollment steps: `hosts/private-laptop/INSTALL.md`.

`vpnClient` is per host in full: each device needs its **own** keypair — the far
end tracks one endpoint per public key, so a shared key means the last device to
handshake steals the session.
