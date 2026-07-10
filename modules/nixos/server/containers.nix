{ pkgs, ... }:
{
  # Turn the dev Podman (from modules/nixos/dev) into a service host: a
  # Docker-API socket at /run/docker.sock for compose/Ansible, timed prune.
  virtualisation.podman = {
    dockerSocket.enable = true;
    autoPrune.enable = true;
  };

  virtualisation.oci-containers.backend = "podman";

  # Ansible runs its modules on the managed node through a Python interpreter
  # (it ships Python over SSH but needs one present to execute); provide it.
  environment.systemPackages = [ pkgs.python3 ];
}
