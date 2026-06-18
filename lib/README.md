# lib/

Shared helper functions.

- `mkHost.nix` — builds a `nixosConfiguration` from a host name + module list,
  wiring in home-manager and common specialArgs, so `flake.nix` stays small.
