# The headless server reboots itself after an autoUpgrade when one is needed.
# The workstations keep `allowReboot = false` from core/updates.nix: nobody
# wants a laptop or desktop to restart under them.
#
# nixos-upgrade only reboots when the new generation's kernel, initrd or kernel
# modules differ from the booted ones. Other updates are applied with a plain
# switch, so most nights no reboot happens. The window keeps a run that started
# late (Persistent= catch-up after downtime, or a manual start of the unit)
# from rebooting the box during the day. A reboot that is skipped is done on the
# next night's run, because the check compares against /run/booted-system.
_: {
  system.autoUpgrade = {
    allowReboot = true;
    # `dates = "daily"` fires at 00:00 plus up to 45 min of randomized delay;
    # the window leaves time for the build to finish.
    rebootWindow = {
      lower = "00:00";
      upper = "05:00";
    };
  };
}
