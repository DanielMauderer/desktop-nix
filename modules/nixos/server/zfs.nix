_: {
  boot = {
    supportedFilesystems.zfs = true;

    # Don't force-import a pool that wasn't cleanly exported (risks data loss).
    zfs.forceImportRoot = false;

    # Import the pre-existing data pool at boot (rename if not "tank").
    zfs.extraPools = [ "tank" ];
  };

  services.zfs.autoScrub.enable = true;
}
