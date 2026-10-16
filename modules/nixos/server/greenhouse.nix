# Greenhouse (OpenGreenhouseManager): the Rust backend services and the Angular
# web app, built from tag-pinned flake inputs (`greenhouse-backend`,
# `greenhouse-web` in flake.nix) and run as native units. Replaces the former
# Ansible + podman deployment (OpenGreenhouseManager/ansible-playbook, archived).
# A release is: bump the tag in flake.nix, push, let CI promote `release`.
#
# Exposure (no new WAN ports; the WAN surface stays UDP 51820 + TCP 80/443):
#   8080       nginx, bound to 127.0.0.1: the static SPA plus `/api` proxied to
#              web_api. NPM reaches it over loopback — its proxy host for the
#              greenhouse domain must point at http://127.0.0.1:8080.
#   5001-5004, 5101-5102
#              the services. They bind 0.0.0.0 (hard-coded upstream) but no
#              firewall rule admits them, so only loopback reaches them. Note
#              the podman stack they replace was reachable from the LAN anyway,
#              because podman's publish DNAT bypasses the input chain.
#
# Database: one database + role per service on the shared cluster
# (postgresql.nix), reached over the socket with peer auth — each unit runs as a
# DynamicUser named after its role, the same pattern as nixpkgs' miniflux.
#
# Config: every binary reads `config/.env` (YAML) relative to its working
# directory; nothing else is read from the environment except RUST_LOG. The file
# is a sops template (it carries the Sentry DSN, and auth also the JWT secret)
# handed over as a systemd credential; the working directory is a store path
# whose `config/.env` symlinks into the unit's credentials directory.
# Secrets: secrets/home-server/greenhouse.yaml (bare values; must not contain
# `"` or `\`, they are spliced into JSON strings).
#
# Logs reach Loki through Alloy like every other unit; device metrics are
# scraped into the box's Prometheus, which device_service queries back.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  backend = inputs.greenhouse-backend.packages.${system}.default;
  web = inputs.greenhouse-web.packages.${system}.default;

  sopsFile = ../../../secrets/home-server/greenhouse.yaml;

  ports = {
    dataStorage = 5001;
    auth = 5002;
    scriptingService = 5003;
    device = 5004;
    webApi = 5101;
    scriptingApi = 5102;
    web = 8080;
  };
  prometheusPort = 9090; # metrics.nix

  local = port: "http://127.0.0.1:${toString port}";
  databaseUrl = role: "host=/run/postgresql user=${role} dbname=${role}";

  # unit name -> binary, database role (null = none), config.
  services = {
    greenhouse-data-storage = {
      bin = "data_storage_service";
      db = "greenhouse_data";
      settings = {
        SERVICE_PORT = ports.dataStorage;
        DATABASE_URL = databaseUrl "greenhouse_data";
      };
    };
    greenhouse-auth = {
      bin = "auth_service";
      db = "greenhouse_auth";
      settings = {
        SERVICE_PORT = ports.auth;
        DATABASE_URL = databaseUrl "greenhouse_auth";
        JWT_SECRET = config.sops.placeholder.greenhouse-jwt-secret;
      };
    };
    greenhouse-scripting-service = {
      bin = "scripting_service";
      db = "greenhouse_scripting";
      settings = {
        SERVICE_PORT = ports.scriptingService;
        DATABASE_URL = databaseUrl "greenhouse_scripting";
        SCRIPTING_API = local ports.scriptingApi;
      };
    };
    greenhouse-device = {
      bin = "device_service";
      db = "greenhouse_device";
      settings = {
        SERVICE_PORT = ports.device;
        DATABASE_URL = databaseUrl "greenhouse_device";
        # Handed to devices on /activate for their alert callbacks; loopback
        # because no LAN device calls back today. A LAN device would need the
        # LAN address here plus a source-restricted rule for :5102.
        SCRIPTING_API = local ports.scriptingApi;
        SCRIPTING_SERVICE = local ports.scriptingService;
        PROMETHEUS_URL = "${local prometheusPort}/api/v1/";
      };
    };
    greenhouse-web-api = {
      bin = "web_api";
      db = null;
      settings = {
        API_PORT = ports.webApi;
        SERVICE_ADDRESSES = {
          AUTH_SERVICE = local ports.auth;
          DEVICE_SERVICE = local ports.device;
          DATA_STORAGE_SERVICE = local ports.dataStorage;
        };
      };
    };
    greenhouse-scripting-api = {
      bin = "scripting_api";
      db = null;
      settings = {
        API_PORT = ports.scriptingApi;
        SERVICE_ADDRESSES = {
          SCRIPTING_SERVICE = local ports.scriptingService;
          DATA_STORAGE_SERVICE = local ports.dataStorage;
        };
      };
    };
  };

  dbRoles = lib.filter (r: r != null) (lib.mapAttrsToList (_: s: s.db) services);

  sentrySecret = name: "${name}-sentry-dsn";

  # The binaries open the relative path config/.env; point it at the credential.
  workingDir =
    name:
    pkgs.runCommand "${name}-cwd" { } ''
      mkdir -p $out/config
      ln -s /run/credentials/${name}.service/config $out/config/.env
    '';

  bootstrapSecrets = [
    "greenhouse-admin-user"
    "greenhouse-admin-password"
    "greenhouse-guest-user"
    "greenhouse-guest-password"
  ];
in
{
  services = {
    postgresql = {
      ensureDatabases = dbRoles;
      ensureUsers = map (name: {
        inherit name;
        ensureDBOwnership = true;
      }) dbRoles;
    };

    # Static SPA + same-origin /api, loopback only; NPM stays the public proxy.
    nginx = {
      enable = true;
      virtualHosts.greenhouse = {
        default = true;
        listen = [
          {
            addr = "127.0.0.1";
            port = ports.web;
          }
        ];
        root = web;
        locations."/".tryFiles = "$uri $uri/ /index.html";
        # No URI part: the backend routes include the /api prefix.
        locations."/api/".proxyPass = local ports.webApi;
      };
    };

    # device_service exposes per-device gauges and queries them back through
    # PROMETHEUS_URL. 15s matches its default query_range step (global is 30s).
    prometheus.scrapeConfigs = [
      {
        job_name = "greenhouse";
        scrape_interval = "15s";
        static_configs = [ { targets = [ "127.0.0.1:${toString ports.device}" ]; } ];
      }
    ];
  };

  sops = {
    secrets =
      lib.genAttrs
        ([ "greenhouse-jwt-secret" ] ++ map sentrySecret (lib.attrNames services) ++ bootstrapSecrets)
        (_: {
          inherit sopsFile;
        });

    # JSON is valid YAML, which is what the services parse.
    templates = lib.mapAttrs (name: s: {
      content = builtins.toJSON (
        s.settings
        // {
          SENTRY_URL = config.sops.placeholder.${sentrySecret name};
          ENVIRONMENT = "production";
        }
      );
      restartUnits = [ "${name}.service" ];
    }) services;
  };

  systemd.services =
    lib.mapAttrs (name: s: {
      description = "Greenhouse ${s.bin}";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ] ++ lib.optional (s.db != null) "postgresql.target";
      requires = lib.optional (s.db != null) "postgresql.target";
      environment.RUST_LOG = "info";
      serviceConfig = {
        ExecStart = "${backend}/bin/${s.bin}";
        DynamicUser = true;
        # Peer auth maps the unit's user onto the role of the same name.
        User = lib.mkIf (s.db != null) s.db;
        LoadCredential = "config:${config.sops.templates.${name}.path}";
        WorkingDirectory = workingDir name;
        # The services panic when the database (or a sibling) is not up yet.
        Restart = "on-failure";
        RestartSec = 5;
      };
    }) services
    // {
      # Creates the admin and guest accounts on a fresh database — what the
      # Ansible role's curl calls did. Idempotent: an existing user is a 4xx
      # that is logged and ignored.
      greenhouse-bootstrap-users = {
        description = "Greenhouse admin/guest account bootstrap";
        wantedBy = [ "multi-user.target" ];
        requires = [ "greenhouse-auth.service" ];
        after = [ "greenhouse-auth.service" ];
        path = [
          pkgs.curl
          pkgs.jq
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          DynamicUser = true;
          LoadCredential = map (n: "${n}:${config.sops.secrets.${n}.path}") bootstrapSecrets;
        };
        script = ''
          auth=${local ports.auth}
          until curl -fsS "$auth/health" >/dev/null; do sleep 2; done
          register() {
            jq -n --rawfile u "$CREDENTIALS_DIRECTORY/$2" --rawfile p "$CREDENTIALS_DIRECTORY/$3" \
              '{username: $u, password: $p}' \
              | curl -sS -o /dev/null -w "$1: %{http_code}\n" -X POST "$auth/$1" \
                  -H 'Content-Type: application/json' --data-binary @-
          }
          register registerAdmin greenhouse-admin-user greenhouse-admin-password
          register registerGuest greenhouse-guest-user greenhouse-guest-password
        '';
      };
    };
}
