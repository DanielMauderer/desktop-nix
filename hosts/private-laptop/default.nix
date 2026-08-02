_: {
  imports = [
    ../../modules/nixos/base
    ../../modules/nixos/desktop
    ../../modules/nixos/waydroid
    ../../modules/nixos/discord
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

  # Second tunnel (wg1) from the provider wg.conf. Off until this host's key is
  # in secrets/private-laptop/vpn.yaml; fill the three fields from the .conf.
  services.vpnClient = {
    # enable = true;                     # ← flip on after the sops step
    address = [ "FILL-ME/32" ]; # Address =
    endpoint = "FILL-ME:51820"; # Endpoint =
    publicKey = "FILL-ME="; # PublicKey =
  };
}
