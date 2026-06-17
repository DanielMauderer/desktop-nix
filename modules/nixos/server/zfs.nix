# ZFS data pool (data only — the OS lives on a separate ext4 SSD, see
# hosts/home-server/disk.nix).
#
# The pool sits on a single logical device exported by a hardware RAID
# controller, so ZFS sees one vdev: it still gives snapshots, compression,
# checksums and cheap NFS-shared datasets, but self-healing/scrubs can only
# *detect* corruption here, not repair it (no redundancy at the ZFS layer — the
# RAID controller owns that). This matches the user's existing setup.
#
# `networking.hostId` (required by ZFS for pool-ownership safety) is set in the
# host's hardware.nix, since it must be unique per machine.
_: {
  # Pull the ZFS kernel module + userland into the system.
  boot.supportedFilesystems.zfs = true;

  # Don't force-import a pool that wasn't cleanly exported (e.g. after a crash) —
  # the safe value, and the default from 26.11 on. The data pool is imported
  # normally via extraPools below; a forced import risks data loss.
  boot.zfs.forceImportRoot = false;

  # Import the pre-existing data pool at boot. Datasets mount at their own ZFS
  # `mountpoint` property (e.g. /tank, /tank/share). Rename "tank" if the pool
  # is called something else.
  boot.zfs.extraPools = [ "tank" ];

  # Monthly scrub to surface latent corruption (detect-only on this single-vdev
  # pool — see the header note).
  services.zfs.autoScrub.enable = true;
}
