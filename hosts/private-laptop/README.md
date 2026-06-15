# private-laptop

**Pilot machine — migrates to NixOS first** ([Ticket 13](../../docs/tickets/13-host-private-laptop-pilot.md)).

- Role: media consumption + some development
- GPU: Intel iGPU — VAAPI/QSV hardware video decode (`hardware.nix`)
- Modules: base, hyprland desktop, theming, shell, neovim, flatpak/media apps;
  power management is power-profiles-daemon (shared desktop stack)
- Disk: declarative via [`disk.nix`](disk.nix) — LUKS2 + ext4 root + ESP
  (DECISIONS 036). Full-disk NixOS; the Silverblue install is wiped.
- Runbook: [`docs/runbooks/private-laptop.md`](../../docs/runbooks/private-laptop.md)

## Files

- `default.nix` — host composition (base + desktop + `hardware.nix`)
- `hardware.nix` — Intel iGPU/VAAPI, firmware, microcode, zram swap, initrd baseline
- `disk.nix` — disko spec (wired in via `flake.nix`, not `default.nix`)
- `hardware/` — holds the generated `hardware-configuration.nix` after install
  (`nixos-generate-config --no-filesystems`; disko owns the filesystem layout)
