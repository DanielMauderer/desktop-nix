_: {
  imports = [
    ../../modules/nixos/base
    ../../modules/nixos/desktop
    ../../modules/nixos/waydroid
    ../../modules/nixos/net
    ./hardware.nix
    # ./hardware/hardware-configuration.nix  # uncomment after install-time
    # `nixos-generate-config --no-filesystems` (see INSTALL.md)
  ];

  networking.hostName = "private-laptop";
  system.stateVersion = "25.05";

  # Roams, so it reaches the share over the VPN (nfsHost defaults to the VPN IP).
  services.homeServerClient = {
    # enable = true;                     # ← after enrollment (INSTALL.md)
    address = "10.100.0.3/32";
  };
}
