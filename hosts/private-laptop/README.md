# private-laptop

Personal laptop — media consumption and light development. Install guide:
[INSTALL.md](INSTALL.md).

- **Role:** media + some dev
- **GPU:** Intel iGPU — VAAPI/QSV hardware video decode (`hardware.nix`)
- **Kernel:** default nixpkgs
- **Modules:** `base` + `desktop` + `waydroid` (Android container) + `net`
  (home-server VPN client — `ssh home-server` + the NFS share, mounted over the
  VPN when roaming; enrolled per INSTALL.md). Laptop power management
  (power-profiles-daemon, brightnessctl) comes with the desktop stack.
- **Monitoring:** pushes host metrics (60s) and warning-level journal to the
  server's Grafana over `wg0` — one low-priority Alloy process, no inbound port.
  Because it pushes rather than being scraped, being asleep or away from the VPN
  is a gap in the graphs, not an alert; the *Last sample age* panel is what says
  when it was last seen. See `modules/nixos/net/telemetry.nix`.
- **Disk:** disko **LUKS2 + ext4 root + ESP**, zram swap. Full-disk single-boot.
- **Monitors:** single internal panel — covered by the shared `laptop-internal`
  kanshi fallback, so no host-specific profile.

`hardware.nix` carries the Intel iGPU/VAAPI enablement, firmware, microcode and
zram. `hardware/` holds the generated `hardware-configuration.nix` (added at
install). If the iGPU is pre-Broadwell (Gen7 or older), switch
`intel-media-driver`/`iHD` to `intel-vaapi-driver`/`i965` in `hardware.nix`.
