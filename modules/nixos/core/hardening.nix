_: {
  # No remote-login surface on the personal machines; the server re-enables it.
  services.openssh.enable = false;

  # Lock the root account: only `maudi` (via sudo) administers the system.
  users.users.root.hashedPassword = "!";

  # Declared explicitly (NixOS defaults firewall on) so intent shows in the
  # host assertions; nftables loads the nft binary for the VM test's ruleset check.
  networking.firewall.enable = true;
  networking.nftables.enable = true;

  # Sudo logging: pty-confine sudo'd commands and mirror to /var/log/sudo.log.
  security.sudo.extraConfig = ''
    Defaults use_pty
    Defaults logfile=/var/log/sudo.log
  '';
}
