# dev

System-level dev tooling — containers. Imported by `base`, so it lands on every
workstation. Language toolchains and the Claude config are per-user and live in
`modules/home/dev`.

- `podman.nix` — Podman + `podman-compose`, with a `docker` compat shim so
  `docker …` / `docker-compose …` muscle memory points at podman.
