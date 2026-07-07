# sops-nix + age. Each host decrypts with its SSH host ed25519 key (converted to
# age); a personal master age key is a recipient on every secret for recovery.
{ pkgs, ... }: {
  # Generate the SSH host ed25519 key at activation time so sops-nix can derive
  # the age identity even with sshd disabled (we need the key file, not the daemon).
  system.activationScripts.sshHostKey = {
    text = ''
      mkdir -p /etc/ssh
      chmod 755 /etc/ssh
      if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
        ${pkgs.openssh}/bin/ssh-keygen \
          -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N "" -C "" >&2
        chmod 600 /etc/ssh/ssh_host_ed25519_key
        chmod 644 /etc/ssh/ssh_host_ed25519_key.pub
      fi
    '';
  };

  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # age-only scheme; do not derive a GnuPG identity from SSH keys.
  sops.gnupg.sshKeyPaths = [ ];
}
