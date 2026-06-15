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
  networking.firewall.enable = true;
}
