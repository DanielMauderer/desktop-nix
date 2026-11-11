{ pkgs, ... }:
{
  # From the chaotic overlay (mkHost `withChaotic`); fetched from its binary
  # cache, never compiled locally.
  boot.kernelPackages = pkgs.linuxPackages_cachyos;

  # scx_lavd: latency-oriented, gaming-tuned sched-ext scheduler, started by
  # scx_loader on boot (switchable at runtime with `scxctl`).
  services.scx-loader = {
    enable = true;
    config.default_sched = "scx_lavd";
  };
}
