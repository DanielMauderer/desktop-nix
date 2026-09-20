let
  # EDIT to match your network. The VPN subnet matches wireguard.nix.
  lanSubnet = "192.168.178.0/24";
  vpnSubnet = "10.100.0.0/24";

  # NFSv4 serves a single pseudo-filesystem rooted at the `fsid=0` export, and
  # anything outside that tree is simply unreachable — a second top-level export
  # of the subvol could not be mounted at all. So it is bind-mounted *into* the
  # pseudo-root instead, and exported as a child.
  subvolSource = "/hdd_pool_1/subvol-101-disk-0";
  subvolMount = "/hdd_pool_1/share/subvol";
  subvolUnit = "hdd_pool_1-share-subvol.mount";
in
{
  services.nfs.server = {
    enable = true;
    # `fsid` is pinned on both exports rather than left to the kernel: hdd_pool_1
    # is an `extraPools` import (zfs.nix), and an auto-derived fsid on a ZFS
    # dataset changes across a re-import, which clients see as ESTALE.
    # The child is exported explicitly so v4 clients can cross the bind mount's
    # filesystem boundary into it; `nohide` keeps v3 behaviour consistent.
    exports = ''
      /hdd_pool_1/share ${lanSubnet}(rw,sync,no_subtree_check,root_squash,fsid=0) ${vpnSubnet}(rw,sync,no_subtree_check,root_squash,fsid=0)
      ${subvolMount} ${lanSubnet}(rw,sync,no_subtree_check,root_squash,fsid=1,nohide) ${vpnSubnet}(rw,sync,no_subtree_check,root_squash,fsid=1,nohide)
    '';
  };

  # The pool is mounted by zfs-mount.service, not by a fileSystems entry, so
  # systemd derives no ordering from the path and would otherwise run this mount
  # against a bare /hdd_pool_1 — creating a shadow mountpoint and bind-mounting
  # a not-yet-imported source. Same class of race the service modules document
  # (see paperless.nix / grafana.nix). requires= not just after=: if the pool
  # fails to import, exporting an empty directory is worse than not exporting.
  fileSystems.${subvolMount} = {
    device = subvolSource;
    fsType = "none";
    options = [
      "bind"
      # nofail keeps this out of local-fs.target's requirements: without it a
      # pool that fails to import fails the mount job, fails local-fs.target and
      # drops the box to emergency.target — and ssh.nix admits SSH on wg0 only,
      # so that is a physical-access recovery. Ordering below still does the work.
      "nofail"
      "x-systemd.requires=zfs-mount.service"
      "x-systemd.after=zfs-mount.service"
    ];
  };

  # exportfs succeeds just as happily on an empty directory, so the export has to
  # wait for the bind mount rather than merely for the network.
  systemd.services.nfs-server = {
    requires = [ subvolUnit ];
    after = [ subvolUnit ];
  };

  # Admit NFSv4 (:2049) only from the LAN and VPN source ranges, never the WAN.
  networking.firewall.extraInputRules = ''
    ip saddr { ${lanSubnet}, ${vpnSubnet} } tcp dport 2049 accept
  '';
}
