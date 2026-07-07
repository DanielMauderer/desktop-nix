# Keyboard: EurKEY (`eu`) — US layout with European chars via AltGr. Set
# system-wide so the TTY and greeter use it too. mkDefault so a host can override.
{ lib, ... }:
{
  time.timeZone = lib.mkDefault "Europe/Berlin";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  services.xserver.xkb.layout = lib.mkDefault "eu";
  console.useXkbConfig = lib.mkDefault true;
}
