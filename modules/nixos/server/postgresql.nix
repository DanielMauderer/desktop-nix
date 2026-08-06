# Shared PostgreSQL server: the box's general-purpose database, for services
# added later. Nothing consumes it today — Forgejo and Paperless keep their
# embedded SQLite (see the note at the bottom) — so this ships as an empty
# cluster plus the pattern for attaching a service to it.
#
# Exposure (no new WAN ports; the WAN surface stays UDP 51820 + TCP 80/443):
#   none. The server listens on the Unix socket /run/postgresql/.s.PGSQL.5432
#   and on nothing else, so there is no port to firewall and no interface to
#   restrict. This module deliberately contains no `networking.firewall` lines;
#   adding one means the design below has changed and has to be argued for.
#
# `enableTCPIP = false` is NOT enough for that, which is the whole reason
# listen_addresses is forced here: upstream renders
#   listen_addresses = if enableTCPIP then "*" else "localhost"
# so the default still binds 127.0.0.1:5432. Loopback is not reachable from the
# network, but "no TCP listener at all" is a property that can be asserted and
# tested, whereas "a listener that we believe nothing can reach" is not. Empty
# is a documented postgres value meaning "do not listen on TCP".
#
# Authentication is upstream's default, on purpose — it is already
#   local all postgres peer map=postgres
#   local all all      peer
# which is exactly what socket-only wants: a role is reachable only by the
# system user of the same name, so no service needs a password and no password
# needs to be in sops. Note `authentication` is a `types.lines` option, so a
# definition here would *append* rules rather than replace them; the flake's
# host assertions guard the rendered result instead (peer present, no `trust`).
#
# Storage: the cluster stays on the SSD root at /var/lib/postgresql/<major>, the
# same SSD/pool split forgejo.nix uses and for the same reason — a write-heavy
# database is latency-bound, and every path under it would need systemd.tmpfiles
# rules, which cannot reach the ZFS pool (tmpfiles runs before zfs-mount.service).
# Durability comes from the nightly pg_dumpall landing on the mirrored pool.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # The dump lands on the redundant pool, next to the forge's and the archive's.
  dumpDir = "/hdd_pool_1/services/postgresql/dump";
in
{
  services.postgresql = {
    enable = true;

    # Pinned, not left to the module default. `dataDir` is
    # /var/lib/postgresql/${package.psqlSchema}, and upstream picks the default
    # package from `system.stateVersion` — which is 25.05 here, i.e. postgresql_16.
    # An unpinned package that moves (a stateVersion bump, or upstream retuning
    # that ladder) would not fail: it would initialise a *new, empty* cluster in
    # a new directory on the next autoUpgrade and leave the old one untouched on
    # disk. Pinning converts that silent data-disappearance into a deliberate,
    # scheduled major upgrade (dump/restore or pg_upgrade, cluster off).
    package = pkgs.postgresql_18;

    # No databases or roles yet — this is a server, not a service. A service
    # that wants one declares it from its *own* module, two lines, e.g.:
    #
    #   services.postgresql.ensureDatabases = [ "myservice" ];
    #   services.postgresql.ensureUsers = [
    #     { name = "myservice"; ensureDBOwnership = true; }
    #   ];
    #
    # With peer auth the service's systemd unit user maps straight onto the role
    # of the same name: no password, no secret, no host/port in its config.
    #
    # A *containerised* consumer cannot reach a Unix socket by default. Prefer
    # bind-mounting /run/postgresql into the container, which keeps the no-TCP
    # property. Turning listen_addresses back on for the podman bridge would
    # also need a source-restricted extraInputRules rule (the shape forgejo.nix
    # uses for :4000), scram-sha-256 host rules and a sops-held password — and it
    # invalidates two host assertions, which is the intended friction.
    ensureDatabases = [ ];
    ensureUsers = [ ];

    # True socket-only. mkForce because upstream sets this in `config`, not as a
    # mkDefault — see the header for why `enableTCPIP = false` alone leaves a
    # loopback listener behind.
    settings.listen_addresses = lib.mkForce "";
  };

  # Nightly dump onto the mirrored ZFS pool — the analogue of forgejo.nix's
  # `forgejo dump` and paperless.nix's `document_exporter`, and the only copy of
  # the databases that survives losing the SSD.
  #
  # `databases` is left empty, which selects `backupAll` (pg_dumpall): that
  # captures roles and globals as well as every database, and it keeps covering
  # new databases as services are added without anyone remembering to edit this
  # list. The dump is a single ${dumpDir}/all.sql.zstd.
  #
  # Retention differs from the forge's `age = "8w"`: this module keeps only the
  # current dump plus one `.prev` generation, so a fault that survives two nights
  # is not recoverable from here. Acceptable while the cluster is empty; revisit
  # (a timer copying dated snapshots aside, or restic) once a service actually
  # stores something irreplaceable in it.
  services.postgresqlBackup = {
    enable = true;
    location = dumpDir;
    compression = "zstd";
    compressionLevel = 9;
  };

  # `location` is on the ZFS pool, and postgresqlBackup declares it through
  # systemd.tmpfiles, which runs before zfs-mount.service. Same fix, and the same
  # reasoning, as npm-data-dirs / forgejo-dump-dirs / paperless-data-dirs: a
  # oneshot inside the consumer's own dependency chain, so it cannot run before
  # the pool is mounted. The early tmpfiles run still creates a shadow directory
  # under the unmounted /hdd_pool_1; it is hidden by the mount and harmless.
  #
  # Only postgresqlBackup.service is a consumer here. Unlike forgejo.service,
  # which lists its dump dir in ReadWritePaths and so fails 226/NAMESPACE on a
  # missing directory, the backup unit has no ProtectSystem confinement — it
  # would merely fail its redirect at dump time. postgresql.service itself never
  # touches this path, so the database does not gain a dependency on the pool.
  systemd.services.postgresql-dump-dirs = {
    requires = [ "zfs-mount.service" ];
    after = [ "zfs-mount.service" ];
    before = [ "postgresqlBackup.service" ];
    requiredBy = [ "postgresqlBackup.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    # /hdd_pool_1/services is shared with npm, forgejo and paperless, whose
    # oneshots also touch it with no ordering between the four, so they must all
    # agree on the result or the last one to run locks the others out of their
    # own subtree. The agreed state is root:root 0755 — world-*traversable*, so
    # each unprivileged service can reach its own directory, while the subtrees
    # stay owned by their service. Do not change this mode here alone.
    #
    # The dump directory itself is 0700 postgres, matching the umask 0077 the
    # backup script writes with: a pg_dumpall contains every database and every
    # role, so it is the most sensitive file on the pool.
    script = ''
      mkdir -p ${dumpDir}
      chmod 0755 /hdd_pool_1 /hdd_pool_1/services
      chown root:postgres /hdd_pool_1/services/postgresql
      chmod 0750 /hdd_pool_1/services/postgresql
      chown postgres:postgres ${dumpDir}
      chmod 0700 ${dumpDir}
    '';
  };

  # psql on the admin's PATH, so `sudo -u postgres psql` works over the socket
  # without going through the service's own closure.
  environment.systemPackages = [ config.services.postgresql.package ];
}
