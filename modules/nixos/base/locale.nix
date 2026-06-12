# Locale / timezone / keyboard.
#
# Keyboard: EurKEY (`eu`) — a US-based layout with European characters
# (ä/ö/ü/ß …) reached via AltGr+a/o/u/s. Ported from MyLinux's
# hypr/conf/keyboard.conf (`kb_layout = eu`), but set system-wide here so the
# TTY and greeter use it too; the Hyprland input block (Ticket 04) matches it.
#
# All values use mkDefault so a host can override.
{ lib, ... }:
{
  time.timeZone = lib.mkDefault "Europe/Berlin";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  services.xserver.xkb.layout = lib.mkDefault "eu";
  console.useXkbConfig = lib.mkDefault true;
}
