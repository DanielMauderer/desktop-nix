# Primary user `maudi`, fish login shell. Ships a throwaway bootstrap password
# as a hash (never plaintext in the store), force-expired at first login so the
# user must set their own. Replace with your own (`mkpasswd -m yescrypt`).
{ pkgs, lib, ... }:
{
  programs.fish.enable = true;

  # Mutable so the forced first-login password change persists across rebuilds.
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
    initialHashedPassword = lib.mkDefault "$y$j9T$0/lIBeVsaJF/i35FJ1nXb.$YLYPbx.IyJUJMOcwnuk1k2YVIkdWrt10SaBFAbrWjg2";
  };

  # Expire maudi's password once (guarded by a stamp file so a later rebuild
  # never re-expires a password the user has since set).
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
