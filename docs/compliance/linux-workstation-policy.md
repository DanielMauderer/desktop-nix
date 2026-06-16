# Linux Workstation Security Policy — `work-laptop` Compliance Mapping

This document maps the corporate **Sicherheitsanforderungen für Linux-Arbeitsplätze**
policy (§1–§4.8) onto the `work-laptop` NixOS host in this repo. It is the
evidence record for an ISMS review: each requirement is marked ✅ satisfied,
🔧 closed-here (a gap this repo fixed), 🔶 partial/deferred, or 📄 organisational
(NixOS cannot enforce it — handled by process/docs).

Config decisions behind the 🔧 items are recorded in [DECISIONS.md](../DECISIONS.md)
entries **039** and **042–044** (pre-go-live audit fixes: per-host update
channel, mechanical lock-bump, managed bootstrap password). The pre-existing ✅
hardening baseline is DECISIONS **037**.

## §4.1 Inventarisierung — 📄 organisational

A Linux asset register with the mandated fields (device type, serial, user,
distribution+version, encryption status, firewall/hardening status, last-update
date) is kept in [INVENTORY.md → Linux asset register](../INVENTORY.md#linux-asset-register-policy-41).
NixOS cannot maintain this; it is updated by hand / at offboarding.

## §4.2 Verschlüsselung — ✅ satisfied

Full-disk encryption is LUKS2 over the whole root device, declared in
`hosts/work-laptop/disk.nix` (1 GiB ESP + LUKS2 container → ext4 `/`). Swap is
zram only, so no plaintext swap partition leaks data. The passphrase strength and
its record in the asset register are operational (§4.1).

## §4.3 Benutzer- und Rechteverwaltung

| Requirement | Status | Evidence |
|---|---|---|
| Personal accounts | ✅ | single `maudi` normal user — `modules/nixos/base/users.nix` |
| Company password policy | 📄 | enforced at the corporate IdP; PAM complexity intentionally **not** added on-device (see Out of scope) |
| No weak/shared default credential | ✅ 🔧 | bootstrap password ships as a yescrypt **hash** (no plaintext in the Nix store) and is force-expired at first login so the user must set their own — `modules/nixos/base/users.nix` (DECISIONS 044) |
| Developers may use sudo (password + logging) | ✅ 🔧 | `maudi` in `wheel`, `wheelNeedsPassword` default (prompts); sudo logging added — `modules/nixos/base/hardening.nix` (`use_pty`, `logfile=/var/log/sudo.log`) |
| No direct root logins | ✅ | root account locked (`hashedPassword = "!"`) + SSH daemon off — `modules/nixos/base/hardening.nix` |
| Logging of security-relevant actions | 🔧 | auditd + rules for privilege escalation and identity/sudoers changes — `modules/nixos/base/audit.nix` |

## §4.4 Updates & Patches

| Requirement | Status | Evidence |
|---|---|---|
| All packages kept current | ✅ 🔧 | daily `system.autoUpgrade`; work-laptop tracks the CI-gated `release` branch, pilot/desktop track `main` — `modules/nixos/base/updates.nix` (DECISIONS 042) |
| Security updates ≤ 72h | 🔧 | **mechanical, not process-dependent:** a scheduled CI job runs `nix flake update` daily and auto-merges on green (`.github/workflows/update-lock.yml`, DECISIONS 043); a green commit reaches `main` within a day and `release` as soon as `main` is green — worst-case window < 72h |
| No EOL systems | ✅ | nixpkgs is `nixos-unstable` (DECISIONS log) |
| Monthly update confirmation | 📄 | process note in [runbooks/compliance-tasks.md](../runbooks/compliance-tasks.md) |

## §4.5 Malware-Schutz ohne klassischen Virenscanner

Run without a classic AV scanner; the mandatory compensating controls:

| Control | Status | Evidence |
|---|---|---|
| Firewall, default-deny inbound | ✅ | `networking.firewall.enable` + nftables — `modules/nixos/base/hardening.nix` |
| Timely security updates (≤ 72h) | 🔧 | scheduled lock-bump + auto-merge + daily auto-upgrade (§4.4, DECISIONS 043) |
| Signed package sources only | ✅ | Nix substituters are cryptographically signed (trusted public keys); no third-party unsigned repos |
| Restricted user rights (sudo on demand) | ✅ | least-privilege single user, sudo prompts (§4.3) |
| VPN + MFA for remote access | 🔶 | WireGuard is templated in `hosts/work-laptop/default.nix` (activated separately with real keys; the template's `config` scope trap from audit S-5 is fixed); MFA enforced at the corporate VPN/IdP |
| SSH hardening (no password logins); keys passphrase-protected | ✅ | SSH **daemon disabled** entirely — no inbound SSH surface. Outbound client keys' passphrases are an operational user obligation |
| Logging of security-relevant events | 🔧 | auditd + persistent journald — `modules/nixos/base/audit.nix` |

## §4.6 System- & Netzwerksicherheit

| Requirement | Status | Evidence |
|---|---|---|
| Local firewall active & configured | ✅ | nftables stateful, default-deny inbound — `hardening.nix` |
| Unneeded services disabled | ✅ | SSH off; laptop ships a desktop/dev set only, no server daemons |
| MFA for external access | 🔶 | corporate VPN/IdP (off-device) |
| VPN mandatory off-network | 🔶 | WireGuard templated (separate activation task) |
| System logging (auth, system events) active | 🔧 | journald set to **persistent** storage + auditd — `modules/nixos/base/audit.nix` |

## §4.7 Datenspeicherung — ✅ satisfied

All on-disk data sits inside the LUKS2 root (§4.2), so confidential and personal
data is encrypted at rest. Use of central company storage (OneDrive/SharePoint)
is an operational recommendation, not a device setting.

## §4.8 Offboarding — 📄 organisational

Secure-wipe, register removal, and credential/key revocation (incl. sops re-key)
are a process — checklist in [runbooks/compliance-tasks.md](../runbooks/compliance-tasks.md).

## Verification

The 🔧 items are guarded so they cannot silently regress:

- **Eval assertions** (`flake.nix` `baseAssertions`, all hosts): auditd enabled,
  `autoUpgrade.dates == "daily"`, the update-channel routing (work-laptop on
  `…/release`, others on `main`; DECISIONS 042), plus the existing SSH-off /
  root-locked / firewall-on checks.
- **VM test** (`flake.nix` `test-base-system`): `auditd.service` active with the
  `priv_esc` rule loaded, `/var/log/sudo.log` configured, journald persistent,
  SSH not running, nftables input hook present.

Run `nix flake check` to exercise both.

## Out of scope (deliberate)

- **PAM password complexity/length on-device** — the company password policy is
  enforced at the IdP; no `pam_pwquality` is added here.
- **WireGuard/VPN activation** — stays templated in `hosts/work-laptop/default.nix`
  and is enrolled separately with real keys/endpoint (needs secrets this repo
  does not hold).
