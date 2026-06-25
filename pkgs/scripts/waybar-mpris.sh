# Waybar custom/mpris: robust now-playing indicator.
#
# Replaces Waybar's built-in `mpris` module, whose D-Bus metadata handling
# intermittently crashed the entire bar (notably on Spotify track changes).
# This wrapper drives `playerctl --follow`, escapes both Pango markup and JSON,
# and never exits non-zero, so a misbehaving player degrades to an empty label
# instead of taking the bar down.

sep=$'\x1f'

emit() {
    status="$1"
    body="$2"
    text="$body"
    # Pango markup escape, then JSON string escape.
    text="${text//&/&amp;}"
    text="${text//</&lt;}"
    text="${text//>/&gt;}"
    text="${text//\\/\\\\}"
    text="${text//\"/\\\"}"
    # Flatten control characters so they can't produce invalid JSON.
    text="${text//$'\n'/ }"
    text="${text//$'\r'/ }"
    text="${text//$'\t'/ }"
    class="stopped"
    case "$status" in
        Playing) class="playing" ;;
        Paused) class="paused" ;;
    esac
    if [ -z "$body" ]; then
        printf '{"text":"","class":"%s"}\n' "$class"
    else
        printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$text" "$text" "$class"
    fi
}

render() {
    status="$1"
    title="$2"
    artist="$3"
    if [ -z "$title$artist" ]; then
        emit "$status" ""
        return
    fi
    icon="󰝚"
    [ "$status" = "Paused" ] && icon="󰏤"
    if [ -n "$artist" ]; then
        emit "$status" "$icon $title — $artist"
    else
        emit "$status" "$icon $title"
    fi
}

while true; do
    playerctl --follow metadata \
        --format "{{status}}${sep}{{title}}${sep}{{artist}}" 2>/dev/null |
        while IFS="$sep" read -r status title artist; do
            render "$status" "$title" "$artist"
        done || true
    # No active player (or playerctl exited): clear the label and back off so
    # the loop doesn't spin. The `|| true` keeps a non-zero playerctl exit (the
    # pipeline fails under `set -o pipefail`) from killing the script here.
    emit "" ""
    sleep 2
done
