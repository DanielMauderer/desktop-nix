{
  config,
  lib,
  pkgs,
  ...
}:
let
  name = "Daniel Mauderer";
  # Signs with the per-host key. ssh-keygen reads the public half from the
  # private key file and signs through the agent if it holds the key, else it
  # asks for the passphrase.
  signingKey = "${config.home.homeDirectory}/.ssh/id_ed25519";
  # All hosts' keys (= github.com/DanielMauderer.keys), so `git log
  # --show-signature` verifies commits made on any machine.
  allowedSigners = map (key: "daniel.mauderer@outlook.com,daniel.mauderer@medicalvalues.de ${key}") [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOJtntfmNWMrSWSeY1aCAVlAbVznwscKjpVF0Z4EWCSs" # work-laptop
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBnrx3NAlRc9BrkMH4hXJ9ocXNDm/yqH36PWClsUq+Ph"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMJ4O/SkjRdmZevXvA3L9ou9rdx1fCbBPAQU1MykZwHR"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAm+h4JjyhM3plsb2UFpq4FuaFvy00uzVr3fpYWVnALH"
  ];
in
{
  # Commit identity for git and jj. Per host, not per repo: work-laptop
  # overrides it with the work address for every repo on that machine.
  options.local.git.email = lib.mkOption {
    type = lib.types.str;
    default = "daniel.mauderer@outlook.com";
    description = "Author email for git and jj commits.";
  };

  config = {
    xdg.configFile."git/allowed_signers".text = lib.concatLines allowedSigners;

    programs = {
      delta = {
        enable = true;
        enableGitIntegration = true;
      };

      git = {
        enable = true;
        package = pkgs.git;
        lfs.enable = true;

        settings = {
          user = {
            inherit name signingKey;
            inherit (config.local.git) email;
          };
          gpg = {
            format = "ssh";
            ssh.allowedSignersFile = "${config.xdg.configHome}/git/allowed_signers";
          };
          commit.gpgSign = true;
          tag.gpgSign = true;
          init.defaultBranch = "main";
          pull.rebase = true;
          push.autoSetupRemote = true;
        };
      };

      # jj reads its own identity and signing config, not git's.
      jujutsu.settings = {
        user = {
          inherit name;
          inherit (config.local.git) email;
        };
        # Sign at push time rather than on every rewrite: jj rewrites commits
        # constantly, and each signature may cost a passphrase prompt.
        signing = {
          behavior = "drop";
          backend = "ssh";
          key = signingKey;
          backends.ssh.allowed-signers = "${config.xdg.configHome}/git/allowed_signers";
        };
        git.sign-on-push = true;
      };
    };
  };
}
