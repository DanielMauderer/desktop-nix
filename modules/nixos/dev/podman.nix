{ pkgs, ... }:
{
  virtualisation.podman = {
    enable = true;
    # `docker` shim → podman so scripts calling `docker` work.
    dockerCompat = true;
    # Rootless containers get DNS between each other on the default network.
    defaultNetwork.settings.dns_enabled = true;
  };

  environment.systemPackages = [ pkgs.podman-compose ];
}
