# waydroid

Android container — opt-in per host. Imported only from the hosts that want
Android apps (private-laptop + desktop); never work-laptop.

- `default.nix` — `virtualisation.waydroid.enable` (pulls the waydroid package,
  lxc tooling, binder kernel bits, `waydroid-container.service`) plus Hyprland
  window rules: float `waydroid.*` toplevels and the `Waydroid` launcher, and
  `idleinhibit` while one is focused.

One-time imperative setup (per machine, not declarative):
```sh
sudo waydroid init          # downloads system + vendor images (add -s GAPPS for Play)
waydroid session start
waydroid show-full-ui
```
Android data lives in `~/.local/share/waydroid` and `/var/lib/waydroid`
(user-owned, kept out of the nix store).
