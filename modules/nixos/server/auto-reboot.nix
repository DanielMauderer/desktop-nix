# The headless server reboots itself after an autoUpgrade when one is needed.
# The workstations keep `allowReboot = false` from core/updates.nix: nobody
# wants a laptop or desktop to restart under them.
#
# nixos-upgrade only reboots when the new generation's kernel, initrd or kernel
# modules differ from the booted ones. Other updates are applied with a plain
# switch whenever they land, so most updates need no reboot. The window keeps the
# 10-minute runs from rebooting the box during the day: a kernel that lands
# outside it is staged with `nixos-rebuild boot`, and the first run inside the
# window reboots into it (update-check.nix lets that run past its "release
# hasn't moved" gate).
_: {
  system.autoUpgrade = {
    allowReboot = true;
    rebootWindow = {
      lower = "00:00";
      upper = "05:00";
    };
  };
}
