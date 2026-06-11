# 12 — Secrets management

- **Status:** open
- **Depends on:** 01
- **Machines:** all (first consumer: work-laptop wireguard)

## Goal

A secrets pattern established *before* the first secret needs committing.
Nothing secret is in the old repos today, but the migration will need:
wireguard configs/keys (wireguard-tools is in daily use), possibly work VPN
credentials, SSH keys, and API tokens. Secrets must be encrypted in git and
decrypted only on the target host at activation time.

## Sub-tasks

- [ ] Decide sops-nix (recommended: YAML files, multiple keys per file, age
      support) vs agenix (simpler, file-per-secret) — record in DECISIONS.md
- [ ] Key scheme: per-host age keys derived from the host's SSH host key
      (`ssh-to-age`), plus a personal master key (stored in password manager)
      that can decrypt everything
- [ ] `.sops.yaml` creation rules: which paths encrypt to which hosts
- [ ] First real secret: wireguard private key + peer config, consumed by
      `networking.wireguard`/`wg-quick` on work-laptop (lands with Ticket 14)
- [ ] Key bootstrap procedure documented for the runbooks: fresh install →
      host key exists → re-key secrets for the new host → rebuild
- [ ] CI consideration: secrets must not block evaluation/builds on runners
      that have no keys

## Testing

- [ ] Baseline: flake check, linters, all host builds, CI green
- [ ] **CI builds all hosts without any private keys present** (negative
      test — proves secrets are activation-time, not eval-time)
- [ ] `nixosTest`: a fixture secret decrypts at activation in a VM (test age
      key injected), correct owner/permissions, not world-readable, absent
      from the nix store (`grep -r` the store path for the plaintext)
- [ ] Manual: wireguard tunnel comes up on real hardware from the encrypted
      config (validated in Ticket 14)

## Open questions

- [ ] sops-nix vs agenix?
- [ ] Where does the master age key live (password manager, hardware token)?
- [ ] Full secrets inventory: wireguard — what else? (work VPN? ssh config?
      jira.nvim tokens? gitlab.nvim token?) Sweep the live machines'
      `~/.config` for credentials during Ticket 13–14.

## Ask when starting

- jira.nvim and gitlab.nvim (from the nvim setup) need API tokens that are
  presumably configured locally today — confirm where they live and whether
  they should move into the secrets scheme or stay machine-local.
