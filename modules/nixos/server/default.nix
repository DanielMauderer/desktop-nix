_: {
  imports = [
    ./ssh.nix
    ./wireguard.nix
    ./reverse-proxy.nix
    ./cloudflare-ddns.nix
    ./dns.nix
    ./containers.nix
    ./forgejo.nix
    ./forgejo-runner.nix
    ./paperless.nix
    ./zfs.nix
    ./nfs.nix
  ];
}
