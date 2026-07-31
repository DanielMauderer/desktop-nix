# pkgs/

Custom packages. Primary use case: the Hyprland helper shell scripts
(`scripts/*`) packaged with `writeShellApplication` so their runtime
dependencies (jq, hyprctl, …) are explicit and shellcheck runs at build time.
