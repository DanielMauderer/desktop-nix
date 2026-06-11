# Locale / timezone / console keymap.
# Defaults assume a German setup; all use mkDefault so a host can override.
{ lib, ... }:
{
  time.timeZone = lib.mkDefault "Europe/Berlin";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
  console.keyMap = lib.mkDefault "de";
}
