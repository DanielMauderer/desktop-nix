# Secrets management (Ticket 12 / DECISIONS 035): sops-nix + age.
#
# Key scheme: each host decrypts using its SSH host ed25519 key converted to age
# (`sops.age.sshKeyPaths`), plus a personal master age key (private half in the
# password manager) that can decrypt every file. No production `sops.secrets`
# are defined yet — the first real secret (work-laptop wireguard key) lands in
# Ticket 14, which sets `sopsFile` on the secret. This module only establishes
# the decryption infrastructure, so a host with sops-nix wired and zero secrets
# builds and activates with no key present — which is exactly what keyless CI
# exercises (the negative test: secrets are activation-time, not eval-time).
#
# The sops-nix NixOS module itself is wired in lib/mkHost.nix (and mirrored into
# the flake's nixosTest nodes), like stylix, to avoid the `_module.args.inputs`
# recursion.
_: {
  # Derive the host's age identity from its SSH host key at activation time.
  # The path is identical on every host, so this needs no per-host `hostname`.
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # age-only scheme; do not derive a GnuPG identity from SSH keys.
  sops.gnupg.sshKeyPaths = [ ];
}
