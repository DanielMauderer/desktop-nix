# Weather station wrapper (OpenGreenhouseManager): the Ambient Weather realtime
# websocket behind the greenhouse smart-device REST API, as a datasource for
# greenhouse.nix's device_service. The upstream NixOS module comes from the
# `weather-station-wrapper` flake input and is added to the host in flake.nix
# (not imported here — see lib/mkHost.nix); this file only configures it.
#
# Exposure: :6001, no firewall rule, so loopback only — device_service runs on
# the same box, so register the device in the greenhouse UI as
# http://127.0.0.1:6001. No new WAN ports.
#
# Secrets: secrets/home-server/weather-station.yaml (bare values), handed to the
# DynamicUser unit via LoadCredential by the upstream module.
{ config, ... }:
let
  sopsFile = ../../../secrets/home-server/weather-station.yaml;
  secret = {
    inherit sopsFile;
    restartUnits = [ "weather-station-wrapper.service" ];
  };
in
{
  sops.secrets = {
    weather-station-api-key = secret;
    weather-station-application-key = secret;
  };

  services.weather-station-wrapper = {
    enable = true;
    apiKeyFile = config.sops.secrets.weather-station-api-key.path;
    applicationKeyFile = config.sops.secrets.weather-station-application-key.path;
  };
}
