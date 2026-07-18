_: {
  # Out-of-tree HID driver for Xbox One/Series controllers: fixes button/axis
  # mapping, rumble, and battery reporting that the stock kernel gets wrong over
  # Bluetooth.
  hardware.xpadneo.enable = true;

  # Xbox One controllers disconnect constantly unless Bluetooth's Enhanced
  # Re-Transmission Mode is disabled. Re-pair the controller after switching.
  boot.extraModprobeConfig = ''
    options bluetooth disable_ertm=1
  '';
}
