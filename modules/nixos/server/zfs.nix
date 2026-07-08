_: {
  boot = {
    supportedFilesystems.zfs = true;

    # Don't force-import a pool that wasn't cleanly exported (risks data loss).
    zfs.forceImportRoot = false;

    # Import the pre-existing data pool at boot. 2x mirror vdevs (4x 4TB),
    # created under the box's former Proxmox install; imported untouched.
    zfs.extraPools = [ "hdd_pool_1" ];
  };

  services.zfs.autoScrub.enable = true;
}
