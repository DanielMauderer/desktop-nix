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
    address = [ "192.168.178.208/24,fde5:32d8:78dc::208/64" ]; # Address =
    endpoint = "9m2lqds859vjlh5k.myfritz.net:52641"; # Endpoint =
    publicKey = "2vaNA56VJJW4MU4zMaQffBCt9Eac5p7lum80988/Nhc="; # PublicKey =
  };
}
