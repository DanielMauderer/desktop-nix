# discord

Discord chat client — opt-in per host. Imported only from the hosts that want it
(private-laptop + desktop); never work-laptop, and not from `base`.

- `default.nix` — installs the official `discord` client into maudi's
  `home.packages`. We previously shipped `vesktop` (community client) but its
  Wayland screenshare had no audio, so we switched to upstream `discord`.
  `discord` is unfree; its name is allow-listed in
  `modules/nixos/apps.nix` (`nixpkgs.config.allowUnfreePredicate`).
