# base

The workstation baseline — imported by every desktop host (private-laptop,
work-laptop, desktop). It is `../core` plus the GUI/workstation extras the
headless home-server deliberately omits.

Imports:
- `../core` — the machine-agnostic baseline (see `core/README.md`).
- `../apps.nix` — GUI apps (Spotify, Zen Browser, mpv, imv) + the unfree allowlist.
- `../dev` — system-side dev (Podman).
- `../virtualisation` — libvirt/KVM.
- `./audio.nix` — PipeWire.
- `./fonts.nix` — system fonts.
- `./home.nix` — wires the `cli`, `neovim` and `dev` home-manager modules.
