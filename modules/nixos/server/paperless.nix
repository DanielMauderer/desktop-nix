# Document archive: native `services.paperless`, SQLite-backed, reachable only
# across the wg0 VPN. Scans dropped into the NFS share are OCR'd, indexed and
# full-text searchable.
#
# Exposure (no new WAN ports; the WAN surface stays UDP 51820 + TCP 80/443):
#   28981  HTTP, admitted only on the wg0 interface — the same posture as host
#          sshd in ssh.nix. Deliberately NOT proxied through NPM: unlike Forgejo
#          there is no public hostname for it, so the archive never answers on
#          the WAN at all. Do not add a proxy host for it in the NPM UI.
#
# The port is left out of `allowedTCPPorts` entirely and admitted per-interface,
# so the "WAN TCP surface is exactly 80/443" assertion in flake.nix keeps
# holding. This is a *host* service, not a published container port, so the
# nixos-fw input chain really does apply here (contrast reverse-proxy.nix, where
# podman's DNAT bypasses it and the bind address is what enforces the VPN).
#
# Storage: everything — SQLite database, search index, thumbnails, the original
# documents and the nightly export — lives on the mirrored ZFS pool. It is the one
# service here whose data is irreplaceable (the paper is usually gone), and it
# is not latency-bound the way Forgejo's git object churn is, so it does not get
# forgejo.nix's SSD/pool split.
{ config, ... }:
let
  dataDir = "/hdd_pool_1/services/paperless";

  # The drop folder lives under the NFS export from nfs.nix, so any client that
  # mounts the share gets an inbox at /mnt/home-server/paperless-inbox.
  inboxDir = "/hdd_pool_1/share/paperless-inbox";

  httpPort = 28981;

  # Units that read or write the directories below. All of them run under
  # ProtectSystem=strict with these paths in ReadWritePaths, so a missing
  # directory fails mount-namespace setup (226/NAMESPACE) before the process
  # starts — see the note on paperless-data-dirs.
  consumers = [
    "paperless-secret-key.service"
    "paperless-scheduler.service"
    "paperless-task-queue.service"
    "paperless-consumer.service"
    "paperless-web.service"
    "paperless-exporter.service"
  ];
in
{
  services.paperless = {
    enable = true;

    inherit dataDir;
    mediaDir = "${dataDir}/media";
    consumptionDir = inboxDir;
    # Upstream's tmpfiles rule for this would set mode 777; it cannot reach the
    # ZFS pool, so paperless-data-dirs sets the mode instead. Kept for intent and
    # so the two agree if the path ever moves off the pool.
    consumptionDirIsPublic = true;

    # Nightly `document_exporter` onto the same pool: a format-independent,
    # restorable copy (documents + metadata as files and JSON) that does not
    # depend on the SQLite schema of the version that wrote it. The analogue of
    # forgejo.nix's nightly dump.
    exporter = {
      enable = true;
      directory = "${dataDir}/export";
    };

    # Listen on all interfaces and let the per-interface firewall rule below
    # restrict it to the VPN — the same arrangement as host sshd. Binding
    # directly to 10.100.0.1 would additionally couple the unit's startup to
    # wireguard-wg0.service, which is only worth it for container publishes that
    # the firewall cannot see.
    address = "0.0.0.0";
    port = httpPort;

    # Admin account, created/updated on start by the scheduler's preStart.
    passwordFile = config.sops.secrets.paperless-admin-password.path;

    settings = {
      # Not a host filter — ALLOWED_HOSTS stays ["*"] — but it is what populates
      # CSRF_TRUSTED_ORIGINS and CORS_ALLOWED_ORIGINS, without which the login
      # POST is rejected. Must match how the UI is actually reached.
      PAPERLESS_URL = "http://10.100.0.1:${toString httpPort}";

      # German and English documents. This narrows the tesseract language data
      # rather than adding a build: tesseractBase is shared with the unrestricted
      # package and the traineddata files are individually cached, so the closure
      # gets *smaller* (~1.0 GiB vs ~1.4 GiB) with nothing built from source.
      PAPERLESS_OCR_LANGUAGE = "deu+eng";

      # Filed documents get readable names instead of UUIDs, which keeps the
      # export (and a bare `ls` over NFS) navigable without the database.
      PAPERLESS_FILENAME_FORMAT = "{created_year}/{correspondent}/{title}";
    };
  };

  sops.secrets.paperless-admin-password = {
    sopsFile = ../../../secrets/home-server/paperless.yaml;
  };

  # Admit the web UI only on the VPN interface, never the WAN. Same pattern as
  # ssh.nix; the port is never added to `allowedTCPPorts`.
  networking.firewall.interfaces.wg0.allowedTCPPorts = [ httpPort ];

  # Every directory above is on the ZFS pool, and upstream declares them through
  # systemd.tmpfiles, which runs before zfs-mount.service. Same fix as
  # npm-data-dirs and forgejo-dump-dirs: a oneshot inside the consumers' own
  # dependency chain, so it cannot run before the pool is mounted. The
  # requiredBy/before pair also orders the consumers after the mount, so those
  # units need no extra ordering of their own.
  #
  # The early tmpfiles run still creates a shadow tree under an unmounted
  # /hdd_pool_1; it is hidden by the mount and harmless. mkForce-ing upstream's
  # tmpfiles settings away would silently drop future rules from that set (the
  # index-dir rule was added exactly that way), so it is left alone.
  systemd.services.paperless-data-dirs = {
    requires = [ "zfs-mount.service" ];
    after = [ "zfs-mount.service" ];
    before = consumers;
    requiredBy = consumers;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    # /hdd_pool_1/services is shared with npm and forgejo, and all three of these
    # oneshots touch it with no ordering between them — so they must agree on the
    # result or the last one to run locks the others out of their own subtree.
    # The agreed state is root:root 0755: world-*traversable* so every unprivileged
    # service can reach its own directory, while each subtree stays 0750 and owned
    # by its service. Only the names of the service directories are visible.
    #
    # The inbox is 0777 without the sticky bit, matching upstream's
    # consumptionDirIsPublic: NFS clients write as their own uid, and paperless
    # must be able to delete those files once consumed — which a sticky directory
    # would forbid, leaving every consumed document behind.
    script = ''
      mkdir -p ${dataDir}/index ${dataDir}/media ${dataDir}/export ${inboxDir}
      chmod 0755 /hdd_pool_1 /hdd_pool_1/services
      # Only the directories this unit creates, never `chown -R`: paperless owns
      # everything it writes below them, and recursing would re-walk the whole
      # document tree on every boot.
      chown paperless:paperless ${dataDir} ${dataDir}/index ${dataDir}/media ${dataDir}/export
      chmod 0750 ${dataDir}
      chown paperless:paperless ${inboxDir}
      chmod 0777 ${inboxDir}
    '';
  };
}
