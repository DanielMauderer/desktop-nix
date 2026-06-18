# home-server — headless services host (DECISIONS 049). The first non-desktop
# machine, so it composes a different stack from the laptops/desktop:
#   core   → boot, locale, networking, nix, secrets, updates, hardening, audit,
#            packages, user (maudi + fish login shell) — the shared baseline,
#            WITHOUT the desktop/workstation extras that `base` adds.
#   dev    → Podman (the container runtime the services build on; reused as-is).
#   server → WireGuard VPN server, VPN-only SSH, WAN firewall (80/443), ZFS data
#            pool, NFS export and the container-host groundwork.
# plus server hardware enablement (hardware.nix: ZFS hostId, LTS kernel, HBA
# modules, zram). The disko SSD layout (disk.nix) is wired in via flake.nix's
# mkHost module list, not here, so a nixosTest importing this file boots off its
# own scratch disk.
#
# Same SHELL as the workstations, nothing else: the cli + neovim home modules are
# wired into maudi's home-manager below (kitty/fastfetch come along but are inert
# on a headless box — their stylix theming targets no-op while stylix stays
# disabled, which it does here since the desktop theming module isn't imported).
_: {
  imports = [
    ../../modules/nixos/core
    ../../modules/nixos/dev
    ../../modules/nixos/server
    ./hardware.nix
    # ./hardware/hardware-configuration.nix  # uncomment after the install-time
    # `nixos-generate-config --no-filesystems` (see hosts/home-server/INSTALL.md)
  ];

  networking.hostName = "home-server";
  system.stateVersion = "25.05";

  # The shared shell (fish + starship + aliases), same as every other host.
  home-manager.users.maudi.imports = [
    ../../modules/home/cli
    ../../modules/home/neovim
  ];

  # SSH is key-only (PasswordAuthentication is off in modules/nixos/server/ssh.nix),
  # so the admin's public key must be enrolled here. Replace the placeholder.
  users.users.maudi.openssh.authorizedKeys.keys = [
    # "ssh-ed25519 AAAA... admin@workstation"
  ];
}
