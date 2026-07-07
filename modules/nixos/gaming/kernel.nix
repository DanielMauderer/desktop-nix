{ pkgs, ... }:
{
  # From the chaotic overlay (mkHost `withChaotic`); fetched from its binary
  # cache, never compiled locally.
  boot.kernelPackages = pkgs.linuxPackages_cachyos;

  # scx_lavd: latency-oriented, gaming-tuned sched-ext scheduler.
  services.scx = {
    enable = true;
    scheduler = "scx_lavd";
  };
}
