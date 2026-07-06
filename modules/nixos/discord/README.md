# discord

Discord chat client — opt-in per host. Imported only from the hosts that want it
(private-laptop + desktop); never work-laptop, and not from `base`.

- `default.nix` — installs `vesktop` (the community client) into maudi's
  `home.packages`. Vesktop is free/open-source (no `allowUnfreePredicate` entry
  needed) and supports Wayland screenshare-with-audio, unlike the official
  unfree `discord` package.
