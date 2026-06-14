# AMD GPU acceleration + tuning (Ticket 11, desktop only). See DECISIONS 029.
#
# The desktop runs an AMD card; mesa/RADV is the NixOS default Vulkan driver and
# needs no extra packages (VAAPI is covered by mesa too). 32-bit support is
# required for the many 32-bit Steam/Proton titles. The laptops have Intel
# graphics and never import this module.
_: {
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # LACT: AMD GPU control daemon + GUI (fan curves, power/clock limits,
  # monitoring). `enable` runs lactd and installs the lact GUI.
  services.lact.enable = true;

  # MangoHud overlay (FPS / frametimes / sensors) for maudi. Set from this
  # desktop-only module via home-manager.users so it does not land on the
  # laptops — the shared modules/home/desktop set is imported by every host.
  home-manager.users.maudi.programs.mangohud = {
    enable = true;
    settings = {
      fps_limit = 0;
      gpu_stats = true;
      cpu_stats = true;
      ram = true;
      vram = true;
      frametime = true;
      gpu_temp = true;
      cpu_temp = true;
    };
  };
}
