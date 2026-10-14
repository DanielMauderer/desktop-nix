{ pkgs, ... }:
{
  virtualisation.podman = {
    enable = true;
    # `docker` shim → podman so scripts calling `docker` work.
    dockerCompat = true;
    # Rootless containers get DNS between each other on the default network.
    defaultNetwork.settings.dns_enabled = true;
  };

  # Resolve Docker-style short names (`postgres:16`) against Docker Hub, so
  # compose files written for docker pull through the shim. Replaces the
  # default settings, which only held two bare [[registry]] blocks.
  virtualisation.containers.registries.settings.unqualified-search-registries = [ "docker.io" ];

  environment.systemPackages = [ pkgs.podman-compose ];
}
