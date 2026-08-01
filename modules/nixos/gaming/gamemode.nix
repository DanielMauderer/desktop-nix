# The high-performance mode for this host.
#
# power-profiles-daemon exposes only balanced/power-saver here and both are
# no-ops: PPD reaches AMD performance through the amd-pstate EPP driver, which
# needs the CPPC MSR that this Zen 2 desktop part doesn't have (amd_pstate fails
# to init, cpufreq falls back to acpi-cpufreq). gamemode's plain governor switch
# works regardless, per game session rather than system-wide.
#
# Only applies to processes launched under `gamemoderun` — for Steam titles set
# the per-game launch option `gamemoderun %command%`.
_: {
  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renice = 10;
        softrealtime = "auto";
        # acpi-cpufreq governors; schedutil is the CachyOS default we return to.
        desiredgov = "performance";
        defaultgov = "schedutil";
      };

      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 1; # /sys/class/drm/card1 — the Vega
        amd_performance_level = "high"; # otherwise "auto"
      };
    };
  };
}
