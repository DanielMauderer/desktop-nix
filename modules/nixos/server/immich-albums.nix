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
    }
    {
      # <name>/ → "<name>"
      root = "exported";
      levels = "1";
    }
    {
      # <year>/<month>/ → "IPhoneBackup <year>", prefixed like the camera tree.
      root = "ICloud";
      levels = "1";
      extraEnv = [ "ALBUM_NAME_POST_REGEX1='^' 'IPhoneBackup '" ];
    }
  ];

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
        "--env-file=${config.sops.templates."immich-albums.env".path}"
        "--env=API_URL=http://127.0.0.1:2283/api/"
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
      ++ [ image ]
    );
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
    path = [ config.virtualisation.podman.package ];
    serviceConfig.Type = "oneshot";
    script = lib.concatMapStringsSep "\n" run trees;
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
