# FRITZ!Box metrics: WAN throughput and volume, DSL sync rates, uptime, read
# from the router over TR-064 (`services.prometheus.exporters.fritz`, the
# pdreker/fritz_exporter package). metrics.nix scrapes it; current up/down
# speed is `rate()` of the WAN byte counters, total volume is `increase()`.
#
# Exposure: :9787 bound to 127.0.0.1, no firewall rule — scraped over
# loopback like every other exporter here. Outbound only to the router's
# TR-064 port (49000) on the LAN. No new WAN ports.
#
# Router side (one-time, by hand): a dedicated FRITZ!Box user (System →
# FRITZ!Box-Benutzer) with "FRITZ!Box Einstellungen" rights, and "Zugriff für
# Anwendungen zulassen" enabled under Heimnetz → Netzwerk → Netzwerkeinstellungen.
#
# Secret: secrets/home-server/fritz.yaml, key `fritz-exporter-password`, bare
# value. Upstream runs the exporter as a static `fritz-exporter` user (not a
# DynamicUser), so the sops file is simply owned by it — no LoadCredential hop.
{ config, ... }:
let
  cfg = config.services.prometheus.exporters.fritz;
in
{
  sops.secrets.fritz-exporter-password = {
    sopsFile = ../../../secrets/home-server/fritz.yaml;
    owner = cfg.user;
    restartUnits = [ "prometheus-fritz-exporter.service" ];
  };

  services.prometheus.exporters.fritz = {
    enable = true;
    listenAddress = "127.0.0.1";
    settings.devices = [
      {
        name = "fritzbox";
        # By IP rather than fritz.box, so the scrape does not depend on the
        # box resolving through the router's DNS. Same LAN as `lanSubnet`
        # in nfs.nix / forgejo.nix / logs.nix.
        hostname = "192.168.178.1";
        username = "prometheus";
        password_file = config.sops.secrets.fritz-exporter-password.path;
      }
    ];
  };
}
