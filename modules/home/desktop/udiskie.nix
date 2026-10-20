_: {
  # Automount USB sticks / SD cards under /run/media/$USER (needs system udisks2).
  services.udiskie = {
    enable = true;
    automount = true;
    notify = true;
    tray = "auto";
  };
}
