_: {
  imports = [
    ../../modules/nixos/base
    ../../modules/nixos/desktop
    ../../modules/nixos/waydroid
    ../../modules/nixos/discord
<<<<<<< HEAD
=======
    # home-server VPN client: `ssh home-server` + the NFS share. Keys, the sops
    # secret (secrets/private-laptop/wireguard.yaml) and the server's public
    # wiring are all in place; only `enable` below is left — flip it on last,
    # once the server is installed and reachable (hosts/private-laptop/INSTALL.md).
>>>>>>> b931bdd (discord and homeserver strategy)
    ../../modules/nixos/net
    ./hardware.nix
    # ./hardware/hardware-configuration.nix  # uncomment after install-time
    # `nixos-generate-config --no-filesystems` (see INSTALL.md)
  ];

  networking.hostName = "private-laptop";
  system.stateVersion = "25.05";

  # Roams, so it reaches the share over the VPN (nfsHost defaults to the VPN IP).
  services.homeServerClient = {
    # enable = true;                     # ← flip on last, once the server is up
    address = "10.100.0.3/32";
  };
}
