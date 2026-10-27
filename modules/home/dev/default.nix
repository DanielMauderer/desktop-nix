# Per-user dev environment. Deliberately holds **no language toolchain**: a
# global cargo/go/node/python/cc silently shadows the one a project pins, and
# which copy wins is invisible at the prompt. Toolchains come from the project's
# own flake devShell, loaded on `cd` by direnv.
{ pkgs, ... }:
{
  imports = [ ./claude.nix ];

  home.packages = with pkgs; [
    claude-code
  ];

  # Settings only — the auth token lives in the keyring (`gh auth login` once
  # per host), so it never ends up in the store.
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      aliases.co = "pr checkout";
    };
  };

  # Personal opt-out, not a project setting — keeps `ng` from prompting.
  home.sessionVariables.NG_CLI_ANALYTICS = "false";

  # The only thing that puts a toolchain on PATH: per-project devShells, loaded
  # automatically on `cd` (fish integration is wired because programs.fish is
  # enabled).
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
