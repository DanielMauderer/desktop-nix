# Gaming stack (Ticket 11) — desktop only.
#
# Net-new functionality: the old Silverblue image had no gaming or GPU config,
# so nothing is ported. Imported only from hosts/desktop/default.nix (NOT from
# modules/nixos/base) so the Intel laptops never pull in the CachyOS kernel,
# Steam or the AMD GPU stack. See DECISIONS 034.
_: {
  imports = [
    ./kernel.nix
    ./steam.nix
    ./gpu.nix
  ];
}
