# Forgejo Actions runner for the local forge. Jobs run as podman containers, so
# workflows migrated from GitHub Actions keep their `runs-on: ubuntu-latest`
# semantics.
#
# `enable`-gated (default off) because it reads the registration token from sops:
# the token only exists once Forgejo is up and an admin has minted one, so the
# secret file cannot be committed ahead of time and keyless CI must still be able
# to evaluate this host. Flip it on in hosts/home-server/default.nix after the
# enrolment step in INSTALL.md — same shape as the vpnClient opt-in.
#
# How it reaches podman: the upstream module sets
# DOCKER_HOST=unix:///run/podman/podman.sock and adds the service to the `podman`
# group automatically when virtualisation.podman is on (it is, via
# containers.nix). The runner is therefore a *host* service holding the socket,
# never a container with the socket bind-mounted — which is what keeps the
# "no service container mounts the management socket" assertion honest.
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
in
{
  options.services.forgejoRunner = {
    enable = lib.mkEnableOption "Forgejo Actions runner executing jobs as podman containers";

    url = lib.mkOption {
      type = lib.types.str;
      default = "https://git.mauderer.work";
      description = ''
        Base URL of the Forgejo instance to register against. The public URL is
        used rather than a LAN address so that the server URL the runner knows
        matches the one jobs see in their `github.server_url` context.
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
        Runner labels mapping `runs-on` values to container images. Changing
        these forces a re-registration, which the upstream module handles.
      '';
    };

    capacity = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2;
      description = "Number of jobs this runner executes concurrently.";
    };
  };

  config = lib.mkIf cfg.enable {
    # An *environment* file, not a bare token: the value must be the literal line
    # `TOKEN=<registration token>`. (cloudflare-ddns.nix wants the opposite — a
    # bare token — so don't copy the format across.)
    sops.secrets.forgejo-runner-token = {
      sopsFile = ../../../secrets/home-server/forgejo.yaml;
    };

    services.gitea-actions-runner = {
      # Forgejo's own fork of act_runner; the gitea-branded default lags behind
      # what a current Forgejo server expects.
      package = pkgs.forgejo-runner;

      # Instance key becomes the unit name (gitea-runner-forgejo.service). Avoid
      # a dash here: the upstream module runs it through systemd path escaping,
      # so "home-server" would come out as gitea-runner-home\x2dserver.
      instances.forgejo = {
        enable = true;
        name = config.networking.hostName;
        inherit (cfg) url labels;
        tokenFile = config.sops.secrets.forgejo-runner-token.path;

        settings = {
          runner.capacity = cfg.capacity;
          container = {
            # `network` is deliberately unset. Leaving it empty is what makes the
            # runner build a throwaway network per job, which is both how service
            # containers are supported and what keeps concurrent jobs (capacity
            # > 1) isolated from each other. Pinning every job to one shared
            # network would trade that away for nothing: jobs reach the forge
            # over its public URL, and the runner's cache server advertises a
            # host address the per-job bridge can route to anyway.
            privileged = false;
            options = "--security-opt=no-new-privileges";
          };
        };
      };
    };
  };
}
