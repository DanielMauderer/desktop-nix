# sunshine

Sunshine game-stream host for Moonlight clients (the TV) — desktop only.

- `default.nix` — enables `services.sunshine` as an autostarted user service with
  the `cap_sys_admin` wrapper (KMS capture), and opens the stream ports to the
  home LAN only (IPv4 `192.168.178.0/24` on `enp34s0`). The web
  UI (TCP 47990) is deliberately not opened: set credentials and pair Moonlight
  from the desktop at `https://localhost:47990`.
