_: {
  # Public HTTP/HTTPS for the Nginx Proxy Manager container.
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  # NPM admin UI: VPN-only, never the WAN.
  networking.firewall.interfaces.wg0.allowedTCPPorts = [ 81 ];

  # Optional declarative starting point if you'd rather Nix own the NPM
  # container instead of a hand-managed compose file.
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
