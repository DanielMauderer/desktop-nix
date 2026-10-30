_: {
  imports = [
    ./ssh.nix
    ./wireguard.nix
    ./ipv6-interface-id.nix
    ./reverse-proxy.nix
    ./cloudflare-ddns.nix
    ./containers.nix
    ./forgejo.nix
    ./forgejo-runner.nix
    ./paperless.nix
    ./immich.nix
    ./ntfy.nix
    ./postgresql.nix
    ./greenhouse.nix
    ./weather-station.nix
    ./metrics.nix
    ./nixos-metrics.nix
    ./backup-metrics.nix
    ./blackbox.nix
    ./fritz.nix
    ./alerts.nix
    ./logs.nix
    ./grafana.nix
    ./zfs.nix
    ./nfs.nix
  ];
}
