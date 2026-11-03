# Photo library: native `services.immich`, served publicly as
# https://photos.mauderer.work through the native nginx reverse proxy
# (reverse-proxy.nix). It indexes the RAW shoots that already live on the NFS
# share as a read-only *external library*, and shares them by account or by link
# — so someone can see a shoot without being given the VPN or the share.
#
# Public rather than VPN-only, the same call as ntfy.nix and for the same kind
# of reason: the people photos are shared with are exactly the people who are
# not on the VPN. Immich has no self-signup (accounts are created by the admin),
# and share links can carry a password and an expiry. The one open window is
# the first visit after install, which creates the admin account — see the
# Immich section of hosts/home-server/INSTALL.md.
#
# Exposure (no new WAN ports; the WAN surface stays UDP 51820 + TCP 80/443):
#   2283  HTTP, bound to 127.0.0.1 and never firewalled open. The only path in
#         is nginx over loopback, which the firewall accepts unconditionally.
#   3003  machine learning, upstream's own loopback listener.
#
# Storage:
#   - The originals stay where they are, in `photosDir` on the share. Immich only
#     reads them: the server unit gets the path as ReadOnlyPaths, so not even a
#     "delete from disk" in the UI can touch a RAW file. The folder layout on the
#     pool remains the source of truth, and nfs.nix's export is unchanged.
#   - `mediaDir` holds Immich's own files — thumbnails, previews, encoded video
#     and anything uploaded through the app (e.g. phone backups) — on the pool,
#     because uploads have no other copy. Thumbnails are derived, but generating
#     them again from a RAW archive takes hours.
#   - The database is in the shared cluster from postgresql.nix (upstream's
#     `database.enable` claims it via ensureDatabases/ensureUsers and adds the
#     vector extensions), so the nightly `pg_dumpall` already covers it. Peer
#     auth over the socket: no password to keep in sops.
#
# Settings are declared here, which makes the admin settings page read-only —
# the same trade as provisioned Grafana dashboards: change it here and rebuild.
# Anything not set below keeps Immich's default. External libraries themselves
# are not part of the config file and are added once in the UI (INSTALL.md).
_:
let
  domain = "photos.mauderer.work";
  httpPort = 2283;

  # EDIT to wherever the shoots live on the share. Immich needs read access
  # only: directories world-traversable (o+x) and files world-readable (o+r),
  # which is what a 022 umask over NFS produces.
  photosDir = "/hdd_pool_1/share/photos";

  mediaDir = "/hdd_pool_1/services/immich";
in
{
  services.immich = {
    enable = true;

    # An explicit address, not upstream's "localhost": nginx proxies to
    # 127.0.0.1, and "localhost" may resolve to ::1 first.
    host = "127.0.0.1";
    port = httpPort;
    openFirewall = false;

    mediaLocation = mediaDir;

    # Face recognition and "search by content" run on the CPU. The first pass
    # over a large archive keeps the box busy for a while; after that only new
    # photos are processed.
    machine-learning.enable = true;

    settings = {
      # Share links are built from this; without it they point at 127.0.0.1.
      server.externalDomain = "https://${domain}";

      # The auto-import: new files under an external library's import path are
      # picked up by the watcher within seconds, and the nightly scan catches
      # anything the watcher missed (e.g. files written while Immich was down).
      library = {
        watch.enabled = true;
        scan = {
          enabled = true;
          cronExpression = "0 3 * * *";
        };
      };
    };
  };

  systemd.services.immich-server.serviceConfig.ReadOnlyPaths = [ photosDir ];

  # Same fix as paperless-data-dirs: the media directory is on the ZFS pool, so
  # it must be created after zfs-mount.service and before the server starts —
  # otherwise the server races the pool and writes into a shadow directory
  # under an unmounted /hdd_pool_1.
  systemd.services.immich-data-dirs = {
    requires = [ "zfs-mount.service" ];
    after = [ "zfs-mount.service" ];
    before = [ "immich-server.service" ];
    requiredBy = [ "immich-server.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    # /hdd_pool_1/services is shared — see paperless.nix for why it is
    # root:root 0755 in every one of these oneshots. The photos directory is
    # only created if missing, as maudi's (who writes to it over NFS), and never
    # touched again: an existing tree keeps its owner and modes.
    script = ''
      [ -d ${photosDir} ] || install -d -m 0755 -o maudi -g users ${photosDir}
      mkdir -p ${mediaDir}
      chmod 0755 /hdd_pool_1 /hdd_pool_1/services
      chown immich:immich ${mediaDir}
      chmod 0700 ${mediaDir}
    '';
  };
}
