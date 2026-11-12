# Discord — chat client, opt-in per host.
#
# Ships the official `discord` package. We previously used `vesktop` (the
# community client) but its Wayland screenshare had no audio in practice, so we
# switched back to the upstream client. `discord` is unfree and is a wrapper
# around `discord-unwrapped`, so both names are allow-listed in
# modules/nixos/apps.nix (nixpkgs.config.allowUnfreePredicate) — the predicate
# runs per derivation, so allow-listing the wrapper alone leaves the build
# failing on its unwrapped dependency.
#
# Imported only from the hosts that want it — private-laptop and desktop — the
# same opt-in set as modules/nixos/waydroid, and NOT from modules/nixos/base and
# NOT by work-laptop.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.local.discord;

  # Discord's voice engine probes VAAPI and, if it finds an H.264 encoder,
  # encodes streams with its in-process Vulkan+VAAPI encoder. On the desktop's
  # Vega 64 that hangs the gfx ring mid-stream, and Vega 10 cannot recover from
  # the reset, so the whole session dies. Pointing libva at a nonexistent driver
  # makes the probe fail and Discord falls back to software OpenH264.
  #
  # Both bin names are wrapped: upstream `bin/discord` is an absolute symlink to
  # its own `bin/Discord` and would bypass a wrapper on just one of them. The
  # .desktop entry runs `Discord` from PATH, so it picks up the wrapper too.
  discord =
    if cfg.softwareEncoding then
      pkgs.symlinkJoin {
        name = "discord-software-encoding";
        paths = [ pkgs.discord ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          for b in discord Discord; do
            rm "$out/bin/$b"
            makeWrapper ${pkgs.discord}/bin/Discord "$out/bin/$b" \
              --set LIBVA_DRIVER_NAME null
          done
        '';
      }
    else
      pkgs.discord;
in
{
  options.local.discord.softwareEncoding = lib.mkEnableOption ''
    software (OpenH264) stream encoding in Discord, hiding VAAPI from it — for
    GPUs whose hardware encode path hangs the GPU while streaming
  '';

  config.home-manager.users.maudi.home.packages = [ discord ];
}
