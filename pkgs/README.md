# pkgs/

Custom packages. Primary use case: the Hyprland helper shell scripts
(`scripts/*`) packaged with `writeShellApplication` so their runtime
dependencies (jq, hyprctl, …) are explicit and shellcheck runs at build time.

`scripts/noctalia-last-update.sh` is the freshness probe for the Noctalia
"last auto-update" bar widget (it queries the GitHub API for the last commit on
the branch `system.autoUpgrade` tracks). `noctalia-plugins/last-update/` is the
matching Noctalia plugin (manifest + Luau bar widget); both are wired up in
`modules/home/desktop/noctalia.nix`.
