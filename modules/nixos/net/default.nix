# net — cross-host networking that reaches OTHER hosts (as opposed to
# modules/nixos/core/networking.nix, which is a host's own baseline). Imported
# explicitly by the machines that need it, not by `base`/`core`.
_: {
  imports = [
    ./home-server-client.nix
  ];
}
