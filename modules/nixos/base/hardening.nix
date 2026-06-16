# Security hardening baseline applied to every host (Ticket 14 / DECISIONS 037).
# These are laptops, not servers — the defaults lean personal-use-safe rather
# than server-permissive.
_: {
  # SSH daemon off: no remote login surface on personal machines. If a host
  # ever needs SSH access, override per-host with `services.openssh.enable =
  # true` and set `PermitRootLogin = "no"` explicitly.
  services.openssh.enable = false;

  # Lock the root account: only `maudi` (via sudo) can administer the system.
  # `nixos-install --no-root-passwd` sets this at install time; the declaration
  # here makes it declarative and audit-visible.
  users.users.root.hashedPassword = "!";

  # Stateful firewall: track established/related connections, drop unsolicited
  # inbound. NixOS's default is `enable = true`, but declaring it explicitly
  # makes the intent visible in host assertions and in the config diff.
  # nftables.enable installs the nft binary and loads rules at boot — required
  # for the VM test assertion `nft list ruleset` to find the command in PATH.
  networking.firewall.enable = true;
  networking.nftables.enable = true;

  # Sudo logging (Linux workstation policy §4.3/§4.5: developer sudo "mit
  # Protokollierung", DECISIONS 039). `use_pty` forces sudo'd commands onto a
  # pseudo-terminal (defeats some session-hijack tricks and keeps tty audit
  # records intact); `logfile` writes a dedicated /var/log/sudo.log in addition
  # to the journal, so privilege use is greppable independent of journald.
  # `wheelNeedsPassword` is left at its secure default (true) — sudo always
  # prompts.
  security.sudo.extraConfig = ''
    Defaults use_pty
    Defaults logfile=/var/log/sudo.log
  '';
}
