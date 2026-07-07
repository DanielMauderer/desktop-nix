# Headless services host: core (not base) + dev (podman) + server, plus the
# shared shell. No desktop stack.
_: {
  imports = [
    ../../modules/nixos/core
    ../../modules/nixos/dev
    ../../modules/nixos/server
    ./hardware.nix
    # ./hardware/hardware-configuration.nix  # uncomment after install-time
    # `nixos-generate-config --no-filesystems` (see INSTALL.md)
  ];

  networking.hostName = "home-server";
  system.stateVersion = "25.05";

  home-manager.users.maudi.imports = [
    ../../modules/home/cli
    ../../modules/home/neovim
  ];

  # SSH is key-only (PasswordAuthentication is off in modules/nixos/server/ssh.nix),
  # so the admin's public key must be enrolled here. Replace the placeholder.
  users.users.maudi.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAm+h4JjyhM3plsb2UFpq4FuaFvy00uzVr3fpYWVnALH maudi@desktop"
  ];
}
