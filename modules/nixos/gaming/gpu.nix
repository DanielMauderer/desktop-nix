_: {
  # 32-bit support is required for 32-bit Steam/Proton titles.
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # AMD GPU control daemon + GUI (fan curves, power/clock limits, monitoring).
  services.lact.enable = true;

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
