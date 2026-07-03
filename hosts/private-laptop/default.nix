# private-laptop — pilot host (Ticket 13). Composes the shared stack:
#   base    → boot, users, networking, audio, nix, fonts, apps, dev, libvirt,
#             secrets + the shell/neovim/dev home modules
#   desktop → Hyprland session, greeter, theming, power-profiles-daemon,
#             brightnessctl + the waybar/kanshi/rofi/etc. home modules
#   waydroid → Android container (opt-in; private-laptop + desktop, DECISIONS 040)
# plus laptop hardware enablement (hardware.nix: Intel iGPU/VAAPI, firmware,
# microcode, zram). The disko disk layout (disk.nix) is wired in via flake.nix's
# mkHost module list, not here, so the nixosTest VMs that import this file boot
# off their own scratch disk.
#
# Monitor layout: the pilot is a single internal panel. The old MyLinux
# p_laptop.conf was just `monitor=,preferred,auto,1`, which the shared
# modules/home/desktop kanshi "laptop-internal" fallback already covers — so no
# host-specific kanshi profile is needed (asserted in flake.nix).
_: {
  imports = [
    ../../modules/nixos/base
    ../../modules/nixos/desktop
    # Waydroid (Ticket 16 / DECISIONS 040) is opt-in per host: the private
    # laptop and desktop run the Android container, work-laptop does not.
    ../../modules/nixos/waydroid
    # home-server VPN client: `ssh home-server` + the NFS share. Enrolled +
    # enabled per hosts/private-laptop/INSTALL.md.
    ../../modules/nixos/net
    ./hardware.nix
    # ./hardware/hardware-configuration.nix  # uncomment after the install-time
    # `nixos-generate-config --no-filesystems` (see hosts/private-laptop/INSTALL.md)
  ];

  networking.hostName = "private-laptop";
  system.stateVersion = "25.05";

  # home-server client. Roams, so it reaches the share over the VPN (nfsHost
  # defaults to the server's VPN IP 10.100.0.1). `enable` stays off until
  # enrollment; flip it on last.
  services.homeServerClient = {
    # enable = true;                     # ← after enrollment (INSTALL.md)
    address = "10.100.0.3/32";
  };
}
