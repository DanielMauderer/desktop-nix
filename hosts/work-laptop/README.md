# work-laptop

Work laptop — heavy development, policy-bound. Install guide:
[INSTALL.md](INSTALL.md).

- **Role:** heavy dev
- **GPU:** Intel iGPU (verify exact model at install) — VAAPI hardware decode
- **Kernel:** default nixpkgs
- **Modules:** `base` + `desktop`. No gaming, no waydroid. WireGuard client +
  sops secrets are wired in (commented template in `default.nix`, enabled at
  install once the secret is enrolled).
- **Disk:** disko **LUKS2 + ext4 root + ESP**, zram swap.
- **Monitors:** kanshi profiles `work-laptop-docked-dual` (DP-5 + DP-6, internal
  off) and `work-laptop-docked-hdmi` (eDP-1 + HDMI-A-1); undocked falls back to
  `laptop-internal`.

## How this host differs (hardening)

This is the one machine with a corporate security policy, so it tightens the
shared baseline:

- **Idle policy:** 5-min screen lock (shared) but auto-suspend lengthened to
  **30 min** so an unattended build or a long docked meeting isn't force-suspended.
- **WireGuard VPN:** the work VPN client (`wg-quick` + sops-nix private key) —
  see [INSTALL.md](INSTALL.md) §VPN. Encrypted full-disk (LUKS), key-only SSH
  inherited from `core`, firewall on, no Android runtime.
- **Corporate CAs:** add any work-issued CAs to `security.pki.certificates` in
  `default.nix` if internal services need them.

`hardware.nix` carries the Intel enablement; `hardware/` holds the generated
`hardware-configuration.nix` (added at install).
