# Headless services host: core (not base) + dev (podman) + server, plus the
# shared shell. No desktop stack.
_: {
  imports = [
    ../../modules/nixos/core
    ../../modules/nixos/dev
    ../../modules/nixos/server
    ./hardware.nix
    # ./hardware/hardware-configuration.nix # RE-ENABLE before nixos-anywhere (generated at install)
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

  # TEMPORARY headless bring-up fallback — REMOVE once VPN reachability is
  # verified (INSTALL.md step 5), then `update`. SSH is otherwise VPN-only
  # (modules/nixos/server/ssh.nix admits :22 on wg0 only); this admits SSH from
  # the LAN so the box is reachable before the WireGuard tunnel exists. LAN-only:
  # the WAN is never in this subnet. Merges with server/nfs.nix's rules.
  networking.firewall.extraInputRules = ''
    ip saddr 192.168.178.0/24 tcp dport 22 accept
  '';
}
