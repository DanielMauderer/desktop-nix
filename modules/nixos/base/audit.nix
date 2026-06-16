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
      "-w /run/wrappers/bin/sudo -p x -k priv_esc"
      "-w /run/current-system/sw/bin/su -p x -k priv_esc"

      # Changes to the identity / authorisation databases.
      "-w /etc/passwd -p wa -k identity"
      "-w /etc/shadow -p wa -k identity"
      "-w /etc/group -p wa -k identity"
      "-w /etc/gshadow -p wa -k identity"
      "-w /etc/sudoers -p wa -k privileges"
      "-w /etc/sudoers.d -p wa -k privileges"

      # System time changes (tamper signal for log correlation).
      "-a always,exit -F arch=b64 -S adjtimex,settimeofday,clock_settime -k time_change"
    ];
  };

  # Persist the journal across reboots so authentication and system events
  # (§4.6) survive a restart — the default "auto" only persists if the journal
  # directory already exists, which is fragile on a fresh install.
  services.journald.storage = "persistent";
}
