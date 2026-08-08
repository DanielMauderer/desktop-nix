# Forgejo Actions runner for the local forge. Jobs run as podman containers, so
# workflows migrated from GitHub Actions keep their `runs-on: ubuntu-latest`
# semantics.
#
# Hand-written unit rather than `services.gitea-actions-runner`, because that
# module only knows the *deprecated* registration flow: it shells out to
# `forgejo-runner register --token …`, and a Forgejo 15 server answers that with
# `invalid_argument: runner registration token not found` no matter how freshly
# the token was minted. Both `register` and `create-runner-file` are marked
# deprecated in forgejo-runner 12.x. The current model inverts the handshake —
# the *forge* creates the runner and hands out its UUID plus a persistent shared
# secret, and the daemon declares the connection at startup:
#
#   forgejo-runner daemon --url … --uuid … --token-url file://…
#
# Consequences worth knowing:
#   - The token is a *bare* value with no trailing newline (the UI literally
#     shows `echo -n`), NOT the `TOKEN=<value>` env-file the old module wanted.
#   - It is a persistent secret, not a one-shot registration token, so there is
#     no re-registration dance on token or label changes — restarting the daemon
#     is enough. (The old module hashed the token into `.token-hash` for exactly
#     that reason.)
#   - `uuid` is forge-specific state, like the token: a rebuilt forge mints new
#     ones, so both must be replaced together on a fresh install (INSTALL.md §5).
#
# `enable`-gated (default off) because the UUID and token only exist once
# Forgejo is up and an admin has created the runner, so keyless CI must still be
# able to evaluate this host. Same shape as the vpnClient opt-in.
#
# How it reaches podman: DOCKER_HOST points at the rootful socket and the unit
# joins the `podman` group. The runner is therefore a *host* service holding the
# socket, never a container with the socket bind-mounted — which is what keeps
# the "no service container mounts the management socket" assertion honest.
#
# SECURITY: that socket is the rootful one, so anyone who can trigger a workflow
# on this forge can become root on home-server. That is only acceptable because
# the instance is single-user (`DISABLE_REGISTRATION`, see forgejo.nix). Do not
# enable Actions on any repository that accepts pull requests from outsiders.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.forgejoRunner;

  settingsFormat = pkgs.formats.yaml { };

  configFile = settingsFormat.generate "forgejo-runner.yaml" {
    runner = {
      file = "/var/lib/forgejo-runner/.runner";
      capacity = cfg.capacity;
    };
    container = {
      # `network` is deliberately left empty. That is what makes the runner build
      # a throwaway network per job, which is both how service containers are
      # supported and what keeps concurrent jobs (capacity > 1) isolated from
      # each other. Pinning every job to one shared network would trade that away
      # for nothing: jobs reach the forge over its public URL, and the runner's
      # cache server advertises a host address the per-job bridge can route to.
      network = "";
      privileged = false;
      options = "--security-opt=no-new-privileges";
    };
  };
in
{
  options.services.forgejoRunner = {
    enable = lib.mkEnableOption "Forgejo Actions runner executing jobs as podman containers";

    url = lib.mkOption {
      type = lib.types.str;
      default = "https://git.mauderer.work";
      description = ''
        Base URL of the Forgejo instance to connect to. The public URL is used
        rather than a LAN address so that the server URL the runner knows matches
        the one jobs see in their `github.server_url` context.
      '';
    };

    uuid = lib.mkOption {
      type = lib.types.str;
      description = ''
        UUID the forge assigned to this runner, shown next to the token in Site
        Administration → Actions → Runners. Not a secret — it identifies the
        runner, the token authenticates it — so it lives in the Nix store rather
        than sops. Only valid for the forge that issued it.
      '';
    };

    labels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        # Node-on-Debian images: most third-party actions are JS actions and need
        # node, git and an FHS-shaped filesystem. `ubuntu-latest` is a deliberate
        # lie so unmodified GitHub workflows still schedule.
        "ubuntu-latest:docker://node:22-bookworm"
        "debian-latest:docker://node:22-bookworm"
        # For flake-based pipelines that want nix in the job itself.
        "nix:docker://nixos/nix:latest"
      ];
      description = ''
        Runner labels mapping `runs-on` values to container images. Passed as
        `--label` on each start, so changing them takes effect on restart.
      '';
    };

    capacity = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2;
      description = "Number of jobs this runner executes concurrently.";
    };
  };

  config = lib.mkIf cfg.enable {
    # A *bare* token — no `TOKEN=` prefix and no trailing newline. The daemon
    # opens this file itself via `--token-url`, unlike the old module which had
    # PID 1 read it as an EnvironmentFile.
    #
    # `restartUnits` is what makes "a token change only needs a restart" true.
    # The unit definition does not depend on the secret's *contents*, and
    # LoadCredential snapshots the file at start — so without this, a `switch`
    # whose only change is the sops file would rewrite /run/secrets and leave the
    # daemon running on the old credential until something else restarted it.
    sops.secrets.forgejo-runner-token = {
      sopsFile = ../../../secrets/home-server/forgejo.yaml;
      restartUnits = [ "forgejo-runner.service" ];
    };

    systemd.services.forgejo-runner = {
      description = "Forgejo Actions Runner";
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "podman.service"
      ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        DOCKER_HOST = "unix:///run/podman/podman.sock";
        HOME = "/var/lib/forgejo-runner";
      };

      path = [ pkgs.coreutils ];

      serviceConfig = {
        DynamicUser = true;
        User = "forgejo-runner";
        StateDirectory = "forgejo-runner";
        WorkingDirectory = "/var/lib/forgejo-runner";
        SupplementaryGroups = [ "podman" ];

        # The token is read by the *runner process* under an unpredictable
        # dynamic UID, so the root-owned file in /run/secrets is not directly
        # readable the way an EnvironmentFile was. LoadCredential has PID 1 copy
        # it into a per-service directory owned by the service user; `%d` expands
        # to that directory. Same pattern forgejo.nix uses for the metrics token.
        LoadCredential = "token:${config.sops.secrets.forgejo-runner-token.path}";

        ExecStart = lib.concatStringsSep " " (
          [
            "${lib.getExe pkgs.forgejo-runner} daemon"
            "--config ${configFile}"
            "--url ${lib.escapeShellArg cfg.url}"
            "--uuid ${lib.escapeShellArg cfg.uuid}"
            "--token-url file://%d/token"
          ]
          ++ map (l: "--label ${lib.escapeShellArg l}") cfg.labels
        );

        # The forge may be restarting during a system upgrade.
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  };
}
