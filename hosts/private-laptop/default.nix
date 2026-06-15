# private-laptop — pilot host (Ticket 13). Composes the shared stack:
#   base    → boot, users, networking, audio, nix, fonts, apps, dev, libvirt,
#             secrets + the shell/neovim/dev home modules
#   desktop → Hyprland session, greeter, theming, power-profiles-daemon,
#             brightnessctl + the waybar/kanshi/rofi/etc. home modules
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
    ./hardware.nix
    # ./hardware/hardware-configuration.nix  # uncomment after the install-time
    # `nixos-generate-config --no-filesystems` (see docs/runbooks/private-laptop.md)
  ];

  networking.hostName = "private-laptop";
  system.stateVersion = "25.05";
}
