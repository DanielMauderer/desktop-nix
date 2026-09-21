{ config, lib, ... }:
let
  plugins = config.security.auditd.plugins;
  rootOwned = {
    mode = "0640";
  };
in
{
  security = {
    auditd.enable = true;
    audit.enable = true;

    audit.rules = [
      # Privilege escalation, keyed for `ausearch -k priv_esc`. Syscall-based,
      # NOT a path watch on sudo: rules load at sysinit before /run/wrappers is
      # populated, so a path watch would ENOENT and abort the whole load. Flag
      # any execve where a logged-in user (auid>=1000) ends up root (euid 0).
      # Both ABIs so 32-bit execve is caught.
      "-a always,exit -F arch=b64 -S execve -F euid=0 -F auid>=1000 -F auid!=4294967295 -k priv_esc"
      "-a always,exit -F arch=b32 -S execve -F euid=0 -F auid>=1000 -F auid!=4294967295 -k priv_esc"

      # Identity/authorisation databases. Only files NixOS maintains — watching
      # /etc/gshadow or /etc/sudoers.d (absent on NixOS) would ENOENT and abort.
      "-w /etc/passwd -p wa -k identity"
      "-w /etc/shadow -p wa -k identity"
      "-w /etc/group -p wa -k identity"
      "-w /etc/sudoers -p wa -k privileges"

      # System time changes (tamper signal for log correlation).
      "-a always,exit -F arch=b64 -S adjtimex,settimeofday,clock_settime -k time_change"
    ];
  };

  # auditd 4.2 refuses any config file it does not see as root-owned and
  # group/other-unwritable. The NixOS module links them straight into the store,
  # which is root-owned on real hardware but not through the virtiofs store
  # export in nixosTests. A `mode` turns each entry into a real root:root copy
  # in /etc, which satisfies the check everywhere.
  environment.etc = {
    "audit/auditd.conf" = rootOwned;
  }
  // lib.mapAttrs' (n: _: lib.nameValuePair "audit/plugins.d/${n}.conf" rootOwned) plugins
  // lib.mapAttrs' (n: _: lib.nameValuePair "audit/audisp-${n}.conf" rootOwned) (
    lib.filterAttrs (_: v: v.settings != null) plugins
  );

  # Persist the journal across reboots ("auto" is fragile on a fresh install).
  services.journald.settings.Journal.Storage = "persistent";
}
