# discord

Discord chat client — opt-in per host. Imported only from the hosts that want it
(private-laptop + desktop); never work-laptop, and not from `base`.

- `default.nix` — installs the official `discord` client into maudi's
  `home.packages`. We previously shipped `vesktop` (community client) but its
  Wayland screenshare had no audio, so we switched to upstream `discord`.
  `discord` is unfree; its name is allow-listed in
  `modules/nixos/apps.nix` (`nixpkgs.config.allowUnfreePredicate`).
  `local.discord.softwareEncoding` wraps it with `LIBVA_DRIVER_NAME=null` so
  streams use software OpenH264 — set on desktop, where Discord's VAAPI encoder
  hangs the Vega 64 beyond recovery.
