# Audio: PipeWire (+ WirePlumber), replacing PulseAudio.
# Bluetooth: just the stack here (DECISIONS 012). A GUI / bar applet is
# deferred to the desktop module (Ticket 04).
_: {
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
}
