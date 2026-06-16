# Compliance process tasks (Linux workstation policy)

The technical controls are enforced in code (DECISIONS 037/039) and verified by
`nix flake check`. This runbook covers the **process** obligations the policy
imposes that NixOS cannot enforce on its own. See the full mapping in
[compliance/linux-workstation-policy.md](../compliance/linux-workstation-policy.md).

## Monthly: confirm updates applied (§4.4)

The system auto-upgrades daily (`modules/nixos/base/updates.nix`), but the policy
requires a monthly user confirmation. Once a month:

1. Check the auto-upgrade ran recently:
   `systemctl status nixos-upgrade.service` (last run < a few days old).
2. Reboot if a kernel/initrd update is staged (`allowReboot = false`, so reboots
   are manual): `journalctl -u nixos-upgrade -b` mentions a new kernel ⇒ reboot.
3. Record the confirmation in the company tracker (Confluence) and update the
   "Last updates" cell in the [asset register](../INVENTORY.md#linux-asset-register-policy-41).

## Offboarding a device (§4.8)

When a Linux device leaves service:

1. **Secure wipe** per ISMS: the disk is LUKS2, so a fast path is to destroy the
   LUKS header / crypto-erase the key slots, then a full `blkdiscard` /
   overwrite of the device. Follow the ISMS-mandated method of record.
2. **Revoke credentials & keys:**
   - Remove the host's age recipient from `.sops.yaml` and run `sops updatekeys`
     on every secret it could decrypt (see [secrets.md](secrets.md)).
   - Revoke the WireGuard peer on the VPN server; remove any VPN/IdP enrolment.
   - Rotate any shared secrets the device held.
3. **Deregister:** remove the device's row from the
   [Linux asset register](../INVENTORY.md#linux-asset-register-policy-41) (and the
   company Confluence copy).
4. Confirm completion to the ISMS owner.
