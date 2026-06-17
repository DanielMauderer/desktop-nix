# Reverse proxy — groundwork for the user's existing Nginx Proxy Manager (NPM).
#
# NPM runs as a container (it manages its own Let's Encrypt certs and binds
# :80/:443), so this module deliberately does NOT enable the declarative
# `services.nginx` — that would fight NPM for the HTTP/HTTPS ports. Instead it
# just opens the WAN-facing web ports and keeps NPM's admin UI (:81) off the
# public internet, reachable only over the VPN.
#
# Migration path (not chosen, to avoid disturbing the working NPM setup):
# `services.nginx` + `security.acme` would move proxying into the Nix config and
# retire the NPM container.
_: {
  # Public HTTP/HTTPS — what NPM (or any proxy container) publishes to the WAN.
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  # NPM admin UI: VPN-only, never the WAN. Merges with the wg0 SSH rule.
  networking.firewall.interfaces.wg0.allowedTCPPorts = [ 81 ];

  # Optional declarative starting point if you'd rather Nix own the NPM
  # container instead of a hand-managed compose file. Persist its data on the
  # ZFS pool (see zfs.nix) so certs/config survive reinstalls.
  #
  # virtualisation.oci-containers.containers.npm = {
  #   image = "jc21/nginx-proxy-manager:latest";
  #   ports = [ "80:80" "443:443" "81:81" ];
  #   volumes = [
  #     "/tank/services/npm/data:/data"
  #     "/tank/services/npm/letsencrypt:/etc/letsencrypt"
  #   ];
  # };
}
