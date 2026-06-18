#!/usr/bin/env bash
#
# install.sh — one-shot NixOS installer for this flake, run from the NixOS
# minimal ISO. It automates the hand-typed steps in hosts/<host>/INSTALL.md:
# disko partitioning, hardware-config generation, wiring the
# generated file into the host, the actual `nixos-install`, and setting maudi's
# password.
#
# THIS WIPES THE TARGET DISK. The disk device comes from the host's disk.nix;
# the script shows it next to `lsblk` and requires an explicit "yes" before
# touching anything (unless --yes is given).
#
# Usage (as root on the installer, after cloning this repo):
#     git clone https://github.com/DanielMauderer/desktop-nix /tmp/cfg
#     /tmp/cfg/scripts/install.sh private-laptop
#
#   ./scripts/install.sh <host> [flags]
#
# Flags:
#   --yes            Skip the destructive-action confirmation prompt.
#   --skip-disko     Don't partition/format — resume after disko already ran
#                    (e.g. a previous attempt got stuck during nixos-install).
#   --skip-hardware  Don't regenerate hardware-configuration.nix — reuse the one
#                    already wired into the host dir.
#   -h, --help       Show this help.
#
# Idempotent enough to re-run: --skip-disko/--skip-hardware let you resume a
# failed install without re-wiping the disk or clobbering a hand-edited hardware
# file.
set -euo pipefail

# --- locate the repo (this script lives in <repo>/scripts/) -----------------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO="$(cd -- "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"

die() {
  echo "install.sh: error: $*" >&2
  exit 1
}

# Re-run a command that fails on transient network drops. nixos-install pulls
# hundreds of paths from the binary cache and a single dropped connection aborts
# the whole run; re-running resumes from the paths already copied into /mnt, so
# retry a few times (exponential backoff) before giving up.
retry() {
  local -i attempt=1 max=4 delay=5
  while true; do
    "$@" && return 0
    [ "$attempt" -lt "$max" ] || return 1
    echo "install.sh: '$1' failed (attempt $attempt/$max); retrying in ${delay}s..." >&2
    sleep "$delay"
    attempt=$((attempt + 1))
    delay=$((delay * 2))
  done
}

usage() {
  # Print the comment header (everything up to the first blank-after-shebang).
  sed -n '2,/^set -euo/{/^set -euo/!p;}' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

# --- parse args -------------------------------------------------------------
HOST=""
ASSUME_YES=0
SKIP_DISKO=0
SKIP_HARDWARE=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --yes | -y) ASSUME_YES=1 ;;
    --skip-disko) SKIP_DISKO=1 ;;
    --skip-hardware) SKIP_HARDWARE=1 ;;
    -h | --help) usage 0 ;;
    -*) die "unknown flag: $1 (try --help)" ;;
    *)
      [ -z "$HOST" ] || die "unexpected extra argument: $1"
      HOST="$1"
      ;;
  esac
  shift
done

[ -n "$HOST" ] || {
  echo "install.sh: missing <host> argument." >&2
  echo >&2
  echo "Available hosts:" >&2
  for d in "$REPO"/hosts/*/disk.nix; do
    [ -e "$d" ] || continue
    echo "  - $(basename "$(dirname "$d")")" >&2
  done
  exit 2
}

HOST_DIR="$REPO/hosts/$HOST"
DISK_NIX="$HOST_DIR/disk.nix"
DEFAULT_NIX="$HOST_DIR/default.nix"
[ -f "$DISK_NIX" ] || die "no such host: '$HOST' (missing $DISK_NIX)"
[ -f "$DEFAULT_NIX" ] || die "missing $DEFAULT_NIX"

# --- must be root: disko/nixos-install write to block devices and /mnt -------
[ "$(id -u)" -eq 0 ] || die "must run as root (use sudo)."

# --- enable flakes + harden binary-cache downloads --------------------------
# Flakes must be on regardless of the installer's own nix config. On top of
# that, installer networks (ISO Wi-Fi, hotel/captive portals, flaky uplinks)
# routinely drop HTTP/2 streams mid-transfer; nix surfaces that as
#   error: ... HTTP error 200 (curl error: Failed sending data to the peer (55))
# against cache.nixos.org, and one failed substitute cascades into a pile of
# "1 dependency failed" build errors and an aborted nixos-install. Forcing
# HTTP/1.1 and trimming the parallel-connection count makes these transfers
# survive lossy links, and connect-timeout fails dead peers fast so a retry can
# pick a healthy one. Both `nix run ... disko` and `nixos-install` read
# NIX_CONFIG, so this covers every download the install performs.
export NIX_CONFIG='experimental-features = nix-command flakes
http2 = false
http-connections = 5
connect-timeout = 10'

# --- show the target disk and confirm (this is the destructive bit) ---------
# disko reads the device from disk.nix; surface it so a wrong device is caught
# before the disk is wiped.
DISK_DEV="$(grep -oP 'device\s*=\s*"\K[^"]+' "$DISK_NIX" | head -n1 || true)"

echo "==> Host:        $HOST"
echo "==> Flake:       $REPO#$HOST"
echo "==> disk.nix:    $DISK_NIX"
echo "==> Target disk: ${DISK_DEV:-<unparsed — check $DISK_NIX>}"
echo
echo "Current block devices:"
lsblk -o NAME,SIZE,TYPE,MODEL,TRAN || true
echo

if [ "$SKIP_DISKO" -eq 0 ]; then
  echo "!! This will ERASE ${DISK_DEV:-the device in disk.nix} and all data on it."
  if [ "$ASSUME_YES" -eq 0 ]; then
    printf 'Type "yes" to continue: '
    read -r reply
    [ "$reply" = "yes" ] || die "aborted by user."
  fi
fi

# --- 1. partition + format with disko ---------------------------------------
if [ "$SKIP_DISKO" -eq 1 ]; then
  echo "==> Skipping disko (--skip-disko); expecting the target mounted at /mnt."
  mountpoint -q /mnt || die "/mnt is not mounted — drop --skip-disko to partition."
else
  echo "==> Partitioning + formatting with disko (will prompt for the LUKS passphrase if this host uses LUKS)..."
  nix run github:nix-community/disko/latest -- --mode disko "$DISK_NIX"
fi

echo "==> Filesystems under /mnt:"
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS | grep -E '/mnt|NAME' || true

# --- 2. hardware-configuration.nix ------------------------------------------
HW_DIR="$HOST_DIR/hardware"
HW_FILE="$HW_DIR/hardware-configuration.nix"
if [ "$SKIP_HARDWARE" -eq 1 ]; then
  echo "==> Skipping hardware-config generation (--skip-hardware)."
  [ -f "$HW_FILE" ] || die "--skip-hardware set but $HW_FILE does not exist."
else
  echo "==> Generating hardware-configuration.nix (--no-filesystems; disko owns the mounts)..."
  nixos-generate-config --no-filesystems --root /mnt
  mkdir -p "$HW_DIR"
  cp /mnt/etc/nixos/hardware-configuration.nix "$HW_FILE"
  echo "==> Wrote $HW_FILE"
fi

# --- 3. uncomment the hardware-config import in default.nix ------------------
# Hosts ship the import commented out (so the nixosTest VMs that import
# default.nix don't pull a non-existent file). Uncomment it for the real
# install if it is still commented.
if grep -qE '^\s*#\s*\./hardware/hardware-configuration\.nix' "$DEFAULT_NIX"; then
  echo "==> Enabling the hardware-configuration.nix import in default.nix"
  sed -i -E 's|^(\s*)#\s*(\./hardware/hardware-configuration\.nix.*)$|\1\2|' "$DEFAULT_NIX"
elif grep -qE '^\s*\./hardware/hardware-configuration\.nix' "$DEFAULT_NIX"; then
  echo "==> hardware-configuration.nix import already enabled."
else
  echo "!! Could not find the hardware-configuration.nix import line in $DEFAULT_NIX." >&2
  echo "!! Add it to the imports list manually before re-running, then use --skip-disko --skip-hardware." >&2
  die "hardware import not wired."
fi

# --- 4. make the new/edited files visible to the flake ----------------------
# Nix evaluates a local flake from git's tracked+staged tree, so the freshly
# copied hardware file (untracked) and the edited default.nix must be staged or
# the build won't see them. Staging is enough — no commit/identity needed.
if [ -d "$REPO/.git" ]; then
  echo "==> Staging generated files so the flake picks them up (git add, no commit)."
  git -C "$REPO" add -A hosts/"$HOST" || true
fi

# --- 5. install -------------------------------------------------------------
echo "==> Installing NixOS: nixos-install --flake $REPO#$HOST --no-root-passwd"
echo "    (root login stays disabled; maudi uses sudo.)"
retry nixos-install --flake "$REPO#$HOST" --no-root-passwd ||
  die "nixos-install failed after repeated attempts. This is usually a flaky
network to cache.nixos.org (curl error 55 / 'Failed sending data to the peer').
Check connectivity ('ping -c1 cache.nixos.org'), then resume without re-wiping
the disk: sudo $SCRIPT_DIR/install.sh $HOST --skip-disko --skip-hardware"

# --- 6. set maudi's password (the config ships no password) -----------------
echo "==> Set a password for the 'maudi' user:"
nixos-enter --root /mnt -c 'passwd maudi'

# --- done -------------------------------------------------------------------
cat <<EOF

==> Done. NixOS is installed for '$HOST'.

Next:
  1. reboot   (remove the installer USB)
  2. At boot you'll get the LUKS passphrase prompt (encrypted hosts), then
     greetd -> Hyprland.
  3. Post-install (see hosts/$HOST/INSTALL.md): clone the repo to
     ~/desktop-nix, enroll this host in secrets, then run
       sudo nixos-rebuild switch --flake ~/desktop-nix#$HOST
EOF
