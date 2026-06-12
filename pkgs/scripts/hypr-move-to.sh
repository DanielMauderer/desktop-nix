# Move every window on the current workspace to the target workspace, then
# follow them there. Bound to SUPER+CTRL+<n>. Ported verbatim from moveTo.sh
# (logging trimmed to stderr).

target_workspace="${1:-}"
if [ -z "$target_workspace" ]; then
    echo "usage: hypr-move-to <workspace>" >&2
    exit 1
fi

current_workspace="$(hyprctl activewindow -j | jq '.workspace.id')"
if [ -z "$current_workspace" ] || [ "$current_workspace" = "null" ]; then
    echo "could not determine current workspace" >&2
    exit 1
fi

mapfile -t addresses < <(
    hyprctl clients -j |
        jq -r ".[] | select(.workspace.id == $current_workspace) | .address"
)

for address in "${addresses[@]}"; do
    hyprctl dispatch movetoworkspacesilent "$target_workspace,address:$address"
done

hyprctl dispatch workspace "$target_workspace"
