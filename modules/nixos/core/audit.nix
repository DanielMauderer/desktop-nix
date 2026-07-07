_: {
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

  # Persist the journal across reboots ("auto" is fragile on a fresh install).
  services.journald.storage = "persistent";
}
