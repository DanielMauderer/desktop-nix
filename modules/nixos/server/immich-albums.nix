# Albums from the folder layout of the photo share. Immich has no folder →
# album feature of its own, so the community tool immich-folder-album-creator
# runs hourly against the API and keeps one album per shoot:
#
#   Camera-dump-raw/2023/levi treffen/…      → "raw-2023 levi treffen"
#   Camera-dump-raw/2026/2026-10-26/100EOSR7 → "raw-2026 2026-10-26" (deeper folders roll up)
#   exported/Alice first shoot/              → "Alice first shoot"
#   ICloud/2022/05/                          → "IPhoneBackup 2022"
#
# Each tree has its own naming rule, so the tool runs once per entry in `trees`.
# It runs in CREATE mode with SYNC_MODE 0, which means it only creates albums and
# adds assets to them. It never deletes an album, including empty hand-made
# ones, and never removes an asset from one. It talks to the API only, so the
# share is not mounted into the container. The photos are still read-only for
# Immich itself (immich.nix).
#
# The API key belongs to the Immich user who will own the albums. It is a sops
# secret (secrets/home-server/immich.yaml, key `immich-album-api-key`, bare
# value), rendered into an env file that podman reads on the host. The key never
# appears on the command line or in the Nix store.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Pinned by digest. Release 2.x needs Immich ≥ 3.0.
  image = "docker.io/salvoxia/immich-folder-album-creator:2.0.3@sha256:0bcb08e37a5de9bf2a2d7c1b1b6898351cd4a244306983e1d8126777dc34e789";

  # Must match the external library's import path as Immich sees it.
  photosDir = "/hdd_pool_1/share/photos";

  # Globs relative to each root; macOS zip debris and camera index files.
  ignore = "**/__MACOSX/**:**/._*:**/*.db";

  trees = [
    {
      # <year>/<shoot>/… → "raw-<year> <shoot>". Albums are matched by name, so
      # the prefix keeps these apart from an `exported/` folder of the same name.
      # The tool has no prefix option; a post-processing regex substitutes one at
      # the start of the name. The tool expects the single quotes inside the
      # value.
      root = "Camera-dump-raw";
      levels = "2";
      extraEnv = [ "ALBUM_NAME_POST_REGEX1='^' 'raw-'" ];
      shared = true;
    }
    {
      # <name>/ → "<name>"
      root = "exported";
      levels = "1";
      shared = true;
    }
    {
      # <year>/<month>/ → "IPhoneBackup <year>", prefixed like the camera tree.
      # Not shared: the phone backups stay private to the owner.
      root = "ICloud";
      levels = "1";
      extraEnv = [ "ALBUM_NAME_POST_REGEX1='^' 'IPhoneBackup '" ];
    }
  ];

  api = "http://127.0.0.1:2283/api";

  # Immich has no "visible to every logged-in user" album, so "shared with
  # everyone" is a share with each user. The list is read from the API at the
  # start of every run (everyone but the key's owner, by email: unique, and it
  # never lands in the repo), so a newly created account is included on the
  # next run. UPDATE_ALBUM_PROPS_MODE=2 is what applies it to albums that
  # already exist; mode 1 shares only on creation. Mode 2 also removes users
  # missing from the list, which with "everyone" only ever means deleted ones.
  # pipefail: a failed curl must stop the run, not hand jq an empty list, which
  # under mode 2 would unshare every album.
  lookupUsers = ''
    set -o pipefail
    api_key=$(sed -n 's/^API_KEY=//p' ${config.sops.templates."immich-albums.env".path})
    me=$(curl -fsS -H "x-api-key: $api_key" ${api}/users/me | jq -r .id)
    share_with=$(curl -fsS -H "x-api-key: $api_key" ${api}/users \
      | jq -r --arg me "$me" '[.[] | select(.id != $me) | .email + "=viewer"] | join(":")')
    unset api_key
  '';

  run =
    tree:
    lib.escapeShellArgs (
      [
        "podman"
        "run"
        "--rm"
        "--pull=missing"
        # The API is on 127.0.0.1:2283 only.
        "--network=host"
        # Output reaches the journal through the unit's stdout already; the
        # default journald log driver would log every line a second time.
        "--log-driver=none"
        "--env-file=${config.sops.templates."immich-albums.env".path}"
        "--env=API_URL=${api}/"
        "--env=ROOT_PATH=${photosDir}/${tree.root}"
        "--env=ALBUM_LEVELS=${tree.levels}"
        "--env=IGNORE=${ignore}"
        "--env=MODE=CREATE"
        "--env=SYNC_MODE=0"
        # By default the tool skips every asset already in *any* album, so a
        # photo hand-added to a sharing album first would never reach its
        # folder album.
        "--env=FIND_ASSETS_IN_ALBUMS=1"
        # No CRON_EXPRESSION: one pass, then exit. The timer does the scheduling.
        "--env=UNATTENDED=1"
      ]
      ++ map (e: "--env=${e}") (tree.extraEnv or [ ])
      ++ lib.optional (tree.shared or false) "--env=UPDATE_ALBUM_PROPS_MODE=2"
    )
    # Expanded by the shell at run time, so outside escapeShellArgs.
    + lib.optionalString (tree.shared or false) " \"--env=SHARE_WITH=$share_with\""
    + " ${image}";
in
{
  sops.secrets.immich-album-api-key = {
    sopsFile = ../../../secrets/home-server/immich.yaml;
  };

  sops.templates."immich-albums.env".content = ''
    API_KEY=${config.sops.placeholder.immich-album-api-key}
  '';

  systemd.services.immich-albums = {
    description = "Create Immich albums from the photo share's folders";
    after = [
      "immich-server.service"
      "network-online.target"
    ];
    wants = [ "network-online.target" ];
    path = [
      config.virtualisation.podman.package
      pkgs.curl
      pkgs.jq
    ];
    serviceConfig.Type = "oneshot";
    script = lookupUsers + lib.concatMapStringsSep "\n" run trees;
  };

  systemd.timers.immich-albums = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      RandomizedDelaySec = "5m";
      Persistent = true;
    };
  };
}
