# Freshness probe for the auto-update source, printed for the Noctalia bar
# widget (pkgs/noctalia-plugins/last-update). "Last auto update" here means the
# last commit on the branch that `system.autoUpgrade` pulls (see
# modules/nixos/core/updates.nix) — if the CI pipeline stops landing commits
# there, the fleet silently stops updating.
#
# We ask GitHub, not the local machine, on purpose: a local metric can't tell
# "pipeline broken" from "this machine is offline". A failed query is reported
# as `offline` (never `stale`) so the widget stays neutral without a network.
#
# Inputs come from the environment (the wrapper in noctalia.nix bakes them in):
#   OWNER/REPO/BRANCH   repo + branch autoUpgrade tracks
#   THRESHOLD_DAYS      go stale past this many days (default 3)
#
# Output is a single line, always exit 0:
#   status=offline
#   status=ok stale=<0|1> days=<n> date=<iso>

owner="${OWNER:-DanielMauderer}"
repo="${REPO:-desktop-nix}"
branch="${BRANCH:-release}"
threshold="${THRESHOLD_DAYS:-3}"

offline() {
    echo "status=offline"
    exit 0
}

resp="$(curl -sf --max-time 5 \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${owner}/${repo}/commits/${branch}")" || offline
# curl can exit 0 with an empty or non-JSON body (proxies, rate-limit pages); the
# `|| offline` guards below keep `set -euo pipefail` from aborting with no output.
[ -n "$resp" ] || offline

date_iso="$(printf '%s' "$resp" | jq -r '.commit.committer.date // empty' 2>/dev/null)" || offline
[ -n "$date_iso" ] || offline

commit_epoch="$(date -d "$date_iso" +%s 2>/dev/null)" || offline
now_epoch="$(date +%s)"

days=$(( (now_epoch - commit_epoch) / 86400 ))
[ "$days" -lt 0 ] && days=0

stale=0
[ "$days" -gt "$threshold" ] && stale=1

echo "status=ok stale=${stale} days=${days} date=${date_iso}"
