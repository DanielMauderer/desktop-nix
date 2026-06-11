# lib/

Shared helper functions. Created in Ticket 01:

- `mkHost.nix` — builds a `nixosConfiguration` from a host name + module list,
  wiring in home-manager and common specialArgs, so `flake.nix` stays small.
