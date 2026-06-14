# CachyOS kernel + sched-ext scheduler (Ticket 11, desktop only).
#
# linuxPackages_cachyos comes from the chaotic-cx/nyx overlay, which the desktop
# host already loads (lib/mkHost.nix `withChaotic = true`). chaotic's module
# also adds its binary cache (https://nyx-cache.chaotic.cx/) to nix.settings, so
# the kernel is fetched as a substitute, never compiled locally. CI pulls it
# from the same cache (configured in .github/workflows/ci.yml). See DECISIONS 029.
{ pkgs, ... }:
{
  boot.kernelPackages = pkgs.linuxPackages_cachyos;

  # sched-ext: scx_lavd is the latency-oriented, gaming-tuned scheduler
  # (DECISIONS 029). The CachyOS kernel ships sched_ext support.
  services.scx = {
    enable = true;
    scheduler = "scx_lavd";
  };
}
