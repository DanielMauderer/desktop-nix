# Primary user. Username is `maudi` on every machine (DECISIONS 007).
# fish is the login shell — replaces the `chsh` step in maudiblue's setup.sh.
# Per-feature groups (libvirtd, gamemode) are added by their own modules.
#
# Bootstrap password (audit S-1, DECISIONS 044): ships as a *hash*
# (`initialHashedPassword`), never plaintext in the world-readable Nix store, and
# is force-expired once at first activation so the user must set their own at
# first login. Replace the hash with your own (`mkpasswd -m yescrypt`), or wire a
# sops `hashedPasswordFile` once host keys are enrolled — see
# modules/nixos/core/README.md.
{ pkgs, lib, ... }:
{
  programs.fish.enable = true;

  # The forced first-login password change below writes to /etc/shadow at
  # runtime, so users must be mutable for that change to persist across rebuilds
  # (audit S-1). Made explicit rather than relying on the `true` default.
  users.mutableUsers = true;

  users.users.maudi = {
    isNormalUser = true;
    description = "maudi";
    shell = pkgs.fish;
    extraGroups = [
      "wheel"
      "networkmanager"
      "dialout"
    ];
    # Hash of a throwaway bootstrap password, force-expired at first login (see
    # below). A hash — not plaintext — so it cannot be read back from the store.
    initialHashedPassword = lib.mkDefault "$y$j9T$0/lIBeVsaJF/i35FJ1nXb.$YLYPbx.IyJUJMOcwnuk1k2YVIkdWrt10SaBFAbrWjg2";
  };

  # Force a password change at first login: expire maudi's password once (set its
  # last-change date to the epoch), guarded by a stamp file so a later rebuild
  # never re-expires a password the user has since set (audit S-1, DECISIONS 044).
  # Ordered after the `users` activation step so the account already exists.
  system.activationScripts.maudiForcePasswordChange = {
    deps = [ "users" ];
    text = ''
      stamp=/var/lib/nixos/.maudi-initial-pw-expired
      if [ ! -e "$stamp" ]; then
        ${pkgs.shadow}/bin/chage -d 0 maudi
        mkdir -p "$(dirname "$stamp")"
        touch "$stamp"
      fi
    '';
  };
}
