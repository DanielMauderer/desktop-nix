# desktop — gaming + dev host (Ticket 15), the last machine off Silverblue.
# Composes the shared stack:
#   base    → boot, users, networking, audio, nix, fonts, apps, dev, libvirt,
#             secrets + the shell/neovim/dev home modules
#   desktop → Hyprland session, greeter, theming + the waybar/kanshi/rofi home
#             modules
#   gaming  → CachyOS kernel, scx, Steam, AMD GPU + LACT, MangoHud (desktop-only)
#   waydroid → Android container (opt-in; private-laptop + desktop, DECISIONS 040)
# plus AMD hardware enablement (hardware.nix: kvm-amd, amd-ucode, amdgpu KMS,
# radeonsi VAAPI, zram). The disko disk layout (disk.nix) is wired in via
# flake.nix's mkHost module list, not here, so the nixosTest VMs that import
# this file boot off their own scratch disk.
{ lib, ... }:
{
  imports = [
    ../../modules/nixos/base
    ../../modules/nixos/desktop
    # Gaming/CachyOS stack is desktop-only (Ticket 11): CachyOS kernel, scx,
    # Steam, AMD GPU + LACT, MangoHud. The laptops (Intel) never import it.
    ../../modules/nixos/gaming
    # Waydroid (Ticket 16 / DECISIONS 040) is opt-in per host: the desktop and
    # private laptop run the Android container, work-laptop does not.
    ../../modules/nixos/waydroid
    ./hardware.nix
    # ./hardware/hardware-configuration.nix  # uncomment after the install-time
    # `nixos-generate-config --no-filesystems` (see hosts/desktop/INSTALL.md)
  ];

  networking.hostName = "desktop";
  system.stateVersion = "25.05";

  # Host-specific kanshi profile: dual-head desktop. Prepended (mkBefore) so it
  # matches ahead of the generic laptop-internal fallback in modules/home/desktop.
  home-manager.users.maudi.services.kanshi.settings = lib.mkBefore [
    {
      profile = {
        name = "desktop";
        outputs = [
          {
            criteria = "DP-3";
            mode = "2560x1440@144";
            position = "0,0";
          }
          {
            criteria = "DP-2";
            mode = "1920x1080@60";
            position = "2560,0";
          }
        ];
      };
    }
  ];
}
