# darktable

darktable RAW photo editor — opt-in per host. Imported only from the hosts that
want it (private-laptop + desktop); never work-laptop, and not from `base`.

- `default.nix` — installs `darktable` into maudi's `home.packages`. RAW files
  still open in merle by default (`modules/nixos/apps.nix`); darktable is for
  editing.
