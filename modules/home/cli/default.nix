{ pkgs, lib, ... }:
{
  imports = [
    ./fish.nix
    ./kitty.nix
    ./fastfetch.nix
    ./lazygit.nix
    ./git.nix
  ];

  home = {
    packages = with pkgs; [
      eza # ls replacement
      bat # cat/less replacement
      fd # find replacement
      ripgrep # rg
      fzf # fuzzy finder
      tree # directory tree
      btop # top replacement
      delta # diff pager used by lazygit
    ];

    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      GIT_EDITOR = "nvim";
    };

    sessionPath = [ "$HOME/.local/bin" ];

    # mkDefault so this module is self-sufficient on a host that loads base but
    # not the desktop module (which also sets 25.05).
    stateVersion = lib.mkDefault "25.05";
  };

  # Grouped under one `programs` attr for the statix repeated-keys lint.
  programs = {
    zoxide = {
      enable = true;
      enableFishIntegration = true;
    };

    # stylix has a starship target, so the palette is themed automatically.
    starship.enable = true;

    # Private key is per-host machine-local state (bootstrap with `ssh-keygen
    # -t ed25519`), not in the repo. AddKeysToAgent → one passphrase per session.
    ssh = {
      enable = true;
      # HM's implicit `Host *` defaults are deprecated; keep the ones we want.
      enableDefaultConfig = false;
      settings = {
        "*" = {
          ForwardAgent = false;
          AddKeysToAgent = "yes";
          Compression = false;
          ServerAliveInterval = 0;
          ServerAliveCountMax = 3;
          HashKnownHosts = false;
          UserKnownHostsFile = "~/.ssh/known_hosts";
          ControlMaster = "no";
          ControlPath = "~/.ssh/master-%r@%n:%p";
          ControlPersist = "no";
        };
        "github.com" = {
          User = "git";
          IdentityFile = "~/.ssh/id_ed25519";
        };
        # Reached over the VPN (its SSH is wg0-only); host must be an enrolled peer.
        "home-server" = {
          User = "maudi";
          HostName = "10.100.0.1";
          IdentityFile = "~/.ssh/id_ed25519";
        };
      };
    };
  };

  services.ssh-agent.enable = true;
}
