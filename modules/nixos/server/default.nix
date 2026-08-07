_: {
  imports = [
    ./ssh.nix
    ./wireguard.nix
    ./reverse-proxy.nix
    ./cloudflare-ddns.nix
    ./containers.nix
    ./forgejo.nix
    ./forgejo-runner.nix
    ./paperless.nix
    ./ntfy.nix
    ./postgresql.nix
    ./metrics.nix
    ./nixos-metrics.nix
    ./backup-metrics.nix
    ./blackbox.nix
    ./alerts.nix
    ./logs.nix
    ./grafana.nix
    ./zfs.nix
    ./nfs.nix
  ];
}
