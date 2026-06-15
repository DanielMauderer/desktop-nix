# 12 — Secrets management

- **Status:** done
- **Depends on:** 01
- **Machines:** all (first consumer: work-laptop wireguard)

> **Outcome (2026-06-15):** sops-nix + age, decided in [DECISIONS 035](../DECISIONS.md).
> Infrastructure only — the first production secret (work-laptop wireguard key)
> lands in Ticket 14. Key bootstrap is documented in
> [runbooks/secrets.md](../runbooks/secrets.md).

## Goal

A secrets pattern established *before* the first secret needs committing.
Nothing secret is in the old repos today, but the migration will need:
wireguard configs/keys (wireguard-tools is in daily use), possibly work VPN
credentials, SSH keys, and API tokens. Secrets must be encrypted in git and
decrypted only on the target host at activation time.

## Sub-tasks

- [x] Decide sops-nix (recommended: YAML files, multiple keys per file, age
      support) vs agenix (simpler, file-per-secret) — record in DECISIONS.md
      → sops-nix (DECISIONS 035)
- [x] Key scheme: per-host age keys derived from the host's SSH host key
      (`ssh-to-age`), plus a personal master key (stored in password manager)
      that can decrypt everything
- [x] `.sops.yaml` creation rules: which paths encrypt to which hosts
- [ ] First real secret: wireguard private key + peer config, consumed by
      `networking.wireguard`/`wg-quick` on work-laptop (deferred to Ticket 14)
- [x] Key bootstrap procedure documented for the runbooks: fresh install →
      host key exists → re-key secrets for the new host → rebuild
      (docs/runbooks/secrets.md)
- [x] CI consideration: secrets must not block evaluation/builds on runners
      that have no keys (activation-time decryption; no production secrets yet)

## Testing

- [x] Baseline: flake check, linters, all host builds, CI green
- [x] **CI builds all hosts without any private keys present** (negative
      test — proves secrets are activation-time, not eval-time): no production
      `sops.secrets` are defined, so `build-hosts` (no keys) is the negative test
- [x] `nixosTest`: a fixture secret decrypts at activation in a VM (test age
      key injected), correct owner/permissions, not world-readable, absent
      from the nix store (`grep -r` the store path for the plaintext) →
      `test-secrets` in flake.nix
- [ ] Manual: wireguard tunnel comes up on real hardware from the encrypted
      config (validated in Ticket 14)

## Open questions

- [x] sops-nix vs agenix? → **sops-nix** (DECISIONS 035)
- [x] Where does the master age key live (password manager, hardware token)? →
      **password manager** (runbooks/secrets.md step 1)
- [ ] Full secrets inventory: wireguard — what else? (work VPN? ssh config?
      jira.nvim tokens? gitlab.nvim token?) Sweep the live machines'
      `~/.config` for credentials during Ticket 13–14.

## Ask when starting

- jira.nvim and gitlab.nvim (from the nvim setup) need API tokens that are
  presumably configured locally today — confirm where they live and whether
  they should move into the secrets scheme or stay machine-local.
  → **Decided:** stay machine-local for now; revisit in the Ticket 13–14
  `~/.config` credential sweep.
