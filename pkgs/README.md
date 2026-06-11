# pkgs/

Custom packages. Primary use case: the shell scripts from MyLinux
(`hypr/scripts/*`, `waybar/scripts/*`) packaged with `writeShellApplication`
so their runtime dependencies (jq, hyprctl, matugen, …) are explicit and
shellcheck runs at build time (Ticket 04).
