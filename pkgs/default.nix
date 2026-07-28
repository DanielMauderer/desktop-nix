# The hypr helper scripts, each wrapped with writeShellApplication so
# shellcheck runs at build time and runtime dependencies are explicit.
#
# hyprctl (from the running session), `noctalia` and `sudo`/`nixos-rebuild` are
# resolved from the ambient PATH, so they're deliberately left out of runtimeInputs.
{ pkgs }:
let
  app =
    name: runtimeInputs:
    pkgs.writeShellApplication {
      inherit name runtimeInputs;
      text = builtins.readFile (./scripts + "/${name}.sh");
    };
in
{
  hypr-focus-mode = app "hypr-focus-mode" (
    with pkgs;
    [
      jq
      libnotify
      procps
    ]
  );

  hypr-move-to = app "hypr-move-to" (with pkgs; [ jq ]);

  theme-sync-wallpaper = app "theme-sync-wallpaper" (
    with pkgs;
    [
      jq
      libnotify
      coreutils
    ]
  );

  # Freshness probe for the Noctalia "last auto-update" bar widget. Queries the
  # GitHub API, so it bundles curl + jq (nothing is assumed on the ambient PATH).
  noctalia-last-update = app "noctalia-last-update" (
    with pkgs;
    [
      curl
      jq
      coreutils
    ]
  );
}
