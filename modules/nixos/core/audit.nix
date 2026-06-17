# Security-event logging (Linux workstation policy §4.3/§4.5/§4.6, DECISIONS 039).
#
# The policy requires "Logging sicherheitsrelevanter Aktionen/Ereignisse" and an
# active system log for authentication and system events. These are laptops, not
# servers, so the audit rule set is deliberately small — privilege escalation and
# changes to the identity/authorisation files — rather than a full CAPP/STIG
# profile that would drown the journal on a developer machine.
_: {
  # Linux kernel audit subsystem + the userspace daemon that persists records to
  # /var/log/audit/audit.log. `auditd.enable` runs auditd; `audit` loads the rule
  # set below at boot via augenrules/auditctl.
  security = {
    auditd.enable = true;
    audit.enable = true;

    audit.rules = [
      # Privilege escalation: record every sudo/su invocation (developer sudo
      # "mit Protokollierung", §4.3) — keyed so `ausearch -k priv_esc` finds them.
      #
      # Syscall-based (not a `-w /run/wrappers/bin/sudo` path watch): NixOS applies
      # these rules from audit-rules-nixos.service at sysinit, long before the
      # setuid wrappers tmpfs (/run/wrappers) is populated, so a path watch would
      # fail with ENOENT and `auditctl -R` would abort the *entire* rule load
      # (DECISIONS 041). Instead, flag any execve where a logged-in user
      # (auid >= 1000) ends up running as root (euid 0) — i.e. sudo/su and kin —
      # which resolves nothing at load time. Both ABIs so 32-bit execve is caught.
      "-a always,exit -F arch=b64 -S execve -F euid=0 -F auid>=1000 -F auid!=4294967295 -k priv_esc"
      "-a always,exit -F arch=b32 -S execve -F euid=0 -F auid>=1000 -F auid!=4294967295 -k priv_esc"

      # Changes to the identity / authorisation databases. Only files NixOS
      # actually maintains: /etc/{passwd,shadow,group} are written by the
      # users-groups activation and /etc/sudoers by the sudo module, so they
      # exist when the rules load. /etc/gshadow and /etc/sudoers.d are *not*
      # created on NixOS — watching them would ENOENT and abort the load too.
      "-w /etc/passwd -p wa -k identity"
      "-w /etc/shadow -p wa -k identity"
      "-w /etc/group -p wa -k identity"
      "-w /etc/sudoers -p wa -k privileges"

      # System time changes (tamper signal for log correlation).
      "-a always,exit -F arch=b64 -S adjtimex,settimeofday,clock_settime -k time_change"
    ];
  };

  # Persist the journal across reboots so authentication and system events
  # (§4.6) survive a restart — the default "auto" only persists if the journal
  # directory already exists, which is fragile on a fresh install.
  services.journald.storage = "persistent";
}
