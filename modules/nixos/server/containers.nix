# Container runtime groundwork for hosting services.
#
# The host already gets Podman from `modules/nixos/dev` (podman + dockerCompat +
# podman-compose), matching the rest of the fleet and the Ansible-deployed
# service that must stay podman-compatible. This module turns that developer
# Podman into a service host:
#
#  - dockerSocket: exposes a Docker-API-compatible socket at /run/docker.sock so
#    the user's `docker compose` stacks and Ansible's community.docker modules
#    drive Podman unchanged (point them at unix:///run/docker.sock).
#  - oci-containers backend = podman: anything later declared under
#    `virtualisation.oci-containers.containers.*` (e.g. the NPM template in
#    reverse-proxy.nix) runs on Podman, not a second Docker daemon.
#  - autoPrune: reclaim dangling images/volumes on a timer so the SSD doesn't
#    fill from churned service images.
#
# Persistent service state belongs on the ZFS data pool (zfs.nix), not the SSD —
# bind-mount it into each container/compose stack (e.g. /tank/services/<svc>).
_: {
  virtualisation.podman = {
    dockerSocket.enable = true;
    autoPrune.enable = true;
  };

  virtualisation.oci-containers.backend = "podman";
}
