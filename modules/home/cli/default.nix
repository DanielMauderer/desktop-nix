# Per-user shell & CLI environment (home-manager) — Ticket 06, Machines: all.
# Ported from the old MyLinux dotfiles (fish/kitty/fastfetch/lazygit), replacing
# the setup.sh symlink flow and the imperative fisher/toolbox installs.
#
# CLI tools live here, not in the base system module (DECISIONS 013). Tools that
# belong to other tickets are deliberately absent: cargo/bacon/nextest, podman,
# git-spice and gh come with the dev environment (Ticket 08); flatpak with
# Ticket 10. The aliases that reference them stay dormant until then.
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
      eza # ls replacement (was cargo/toolbox in the old setup)
      bat # cat/less/more replacement
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

    # Replaces `set -gx PATH $PATH ~/.local/bin` from config.fish.
    sessionPath = [ "$HOME/.local/bin" ];

    # mkDefault so this module is self-sufficient on a hypothetical host that
    # loads base but not the desktop module (which also sets 25.05).
    stateVersion = lib.mkDefault "25.05";
  };

  # Grouped under one `programs` attr (statix repeated-keys lint) rather than
  # separate `programs.zoxide`/`programs.starship`/`programs.ssh` assignments.
  programs = {
    # zoxide ships a fish hook (the `z`/`zi` smart-cd) — enable its integration
    # rather than just dropping the binary in.
    zoxide = {
      enable = true;
      enableFishIntegration = true;
    };

    # Prompt: starship (declarative) replaces the old fisher-installed tide, whose
    # state lived in universal variables and was not reproducible (DECISIONS 023).
    # stylix has a starship target, so the palette is themed automatically.
    starship.enable = true;

    # Declarative ~/.ssh/config. The ssh-agent service below holds keys; this tells
    # ssh to use the host's ed25519 key for GitHub and to load it into the agent on
    # first use (AddKeysToAgent = "yes" → one passphrase prompt per session, not
    # per shell). The private key itself is per-host machine-local state, NOT in
    # the repo: bootstrap each host once with `ssh-keygen -t ed25519` and add the
    # .pub to GitHub (`gh ssh-key add ~/.ssh/id_ed25519.pub`). Remotes use
    # git@github.com.
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
      };
    };
  };

  # The old config did `eval (ssh-agent -c)` in config.fish, spawning a fresh
  # agent per shell. The home-manager service starts one agent and exports
  # SSH_AUTH_SOCK for the session instead.
  services.ssh-agent.enable = true;
}
