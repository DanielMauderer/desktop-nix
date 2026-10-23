{
  inputs,
  pkgs,
  lib,
  ...
}:
{
  # Single authoritative unfree allow-list (only one may be defined per host).
  # Listing steam here only permits it — nothing installs it on the laptops.
  # The predicate is asked about every derivation, so wrapper packages need
  # their `-unwrapped` (and friends) listed too, not just the wrapper's name.
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "spotify"
      "claude-code"
      "discord"
      "discord-unwrapped"
      "steam"
      "steam-unwrapped"
      "steam-original"
      "steam-run"
    ];

  home-manager.users.maudi = {
    home.packages = [
      pkgs.spotify
      inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.twilight
      pkgs.mpv
      pkgs.imv
      inputs.merle.packages.${pkgs.stdenv.hostPlatform.system}.default
      pkgs.imhex
    ];

    # merle ships no .desktop file. merle-view takes exactly one path, hence %f.
    xdg.desktopEntries.merle-view = {
      name = "merle";
      genericName = "RAW Photo Viewer";
      exec = "merle-view %f";
      terminal = false;
      categories = [
        "Graphics"
        "Viewer"
      ];
      mimeType = [
        "image/x-canon-cr2"
        "image/x-canon-cr3"
      ];
    };

    # Declarative mimeapps.list. force replaces the file that apps used to edit
    # in place, so every handler they had registered is carried over here.
    xdg.configFile."mimeapps.list".force = true;
    xdg.mimeApps = {
      enable = true;
      defaultApplications =
        lib.genAttrs [
          "image/png"
          "image/jpeg"
          "image/gif"
          "image/webp"
          "image/bmp"
          "image/tiff"
          "image/svg+xml"
          "image/avif"
          "image/heif"
          "image/jxl"
          "image/qoi"
          "image/x-adobe-dng"
        ] (_: "imv.desktop")
        // {
          "image/x-canon-cr2" = "merle-view.desktop";
          "image/x-canon-cr3" = "merle-view.desktop";
          "application/zip" = "thunar.desktop";
          "x-scheme-handler/discord" = "vesktop.desktop";
          "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
        };
    };
  };
}
