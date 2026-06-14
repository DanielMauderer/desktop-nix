# Podman (Ticket 08) — replaces the toolbox/Silverblue container runtime.
#
# `dockerCompat` installs a `docker` shim → podman so scripts/Makefiles that call
# `docker` work; the interactive fish `docker`→podman alias (Ticket 06) shadows
# it for shells. podman-compose covers the old `docker-compose` workflows.
{ pkgs, ... }:
{
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    # Rootless containers get DNS between each other on the default network.
    defaultNetwork.settings.dns_enabled = true;
  };

  environment.systemPackages = [ pkgs.podman-compose ];
}
