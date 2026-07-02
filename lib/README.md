# lib/

Shared helper functions.

- `mkHost.nix` — builds a `nixosConfiguration` from a module list (plus optional
  `withChaotic`), wiring in home-manager and common specialArgs, so `flake.nix`
  stays small. Each host sets its own `networking.hostName` in
  `hosts/<name>/default.nix`.
