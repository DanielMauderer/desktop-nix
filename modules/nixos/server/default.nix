_: {
  imports = [
    ./ssh.nix
    ./wireguard.nix
    ./reverse-proxy.nix
    ./containers.nix
    ./zfs.nix
    ./nfs.nix
  ];
}
