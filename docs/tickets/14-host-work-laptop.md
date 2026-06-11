# 14 — Host: work-laptop + migration runbook

- **Status:** open
- **Depends on:** 08, 09, 12, 13
- **Machines:** work-laptop

## Goal

The work machine on NixOS: full dev environment, virtualisation, secrets
(wireguard/VPN), and the docked monitor setups. Migrated second, after pilot
lessons are applied. Highest stakes for daily-driver continuity — the runbook
must minimize downtime.

## Sub-tasks

- [ ] Compose `hosts/work-laptop/default.nix`: base + desktop + theming +
      shell + neovim + **full dev (08)** + libvirt (09) + secrets (12)
- [ ] Hardware config + iGPU identification + laptop power (reuse pilot
      decisions)
- [ ] Monitor layouts: port `w_laptop`, `w_laptop_1Monitor`,
      `w_laptop_2Monitors` semantics — implement the dock/undock solution
      decided in Ticket 04 (kanshi profiles per dock state vs manual toggle)
- [ ] Wireguard/VPN via the secrets scheme; verify work VPN connectivity
      requirements (anything beyond wireguard?)
- [ ] Work tooling sweep on the live system before migration: ssh configs,
      git identities/signing, jira/gitlab tokens (nvim plugins), container
      registries, certificates
- [ ] Write `docs/runbooks/work-laptop.md` (pilot runbook as template) with
      work-specific sections: migration scheduled outside work hours,
      definition of "ready for Monday" (checklist), VPN + repo access
      verified before wiping anything
- [ ] Execute the migration; backport lessons to modules

## Testing

- [ ] Baseline: flake check, linters, all host builds, CI green
- [ ] `nixosTest` accumulation: this host's config passes the base/desktop/
      dev/libvirt/secrets VM tests (podman run, virsh list, secret decrypt)
- [ ] Acceptance = runbook hardware checklist: dock/undock both monitor
      setups (the 1-monitor and 2-monitor layouts render correctly,
      workspaces pinned right), wireguard tunnel up, work repos clone/build
      in a devshell, VMs boot, jira/gitlab nvim integrations work
- [ ] A representative work project builds + tests green in its devshell
      before the old system is wiped (hard gate)

## Open questions

- [ ] Work compliance constraints: mandated disk encryption (LUKS — decided
      in 13?), screen-lock timeout policy, anything contractual about OS
      choice worth checking?
- [ ] Are work projects' build environments reproducible via devshells, or do
      any need containers/distrobox fallback?
- [ ] Downtime window: weekend migration with the old SSD kept bootable?

## Ask when starting

- The `monitor-hotplug.sh` cycle order (w_laptop → 1Monitor → 2Monitors)
  encodes the real desk setups — confirm both docked layouts are still
  current before porting them.
- Confirm which VPN(s) the work flow actually needs (only wireguard, or
  corporate clients too).
