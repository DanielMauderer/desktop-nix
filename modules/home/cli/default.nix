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
  ];

  home.packages = with pkgs; [
    eza # ls replacement (was cargo/toolbox in the old setup)
    bat # cat/less/more replacement
    fd # find replacement
    ripgrep # rg
    fzf # fuzzy finder
    tree # directory tree
    btop # top replacement
    delta # diff pager used by lazygit
  ];

  # zoxide ships a fish hook (the `z`/`zi` smart-cd) — enable its integration
  # rather than just dropping the binary in.
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  # Prompt: starship (declarative) replaces the old fisher-installed tide, whose
  # state lived in universal variables and was not reproducible (DECISIONS 023).
  # stylix has a starship target, so the palette is themed automatically.
  programs.starship.enable = true;

  # The old config did `eval (ssh-agent -c)` in config.fish, spawning a fresh
  # agent per shell. The home-manager service starts one agent and exports
  # SSH_AUTH_SOCK for the session instead.
  services.ssh-agent.enable = true;

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    GIT_EDITOR = "nvim";
  };

  # Replaces `set -gx PATH $PATH ~/.local/bin` from config.fish.
  home.sessionPath = [ "$HOME/.local/bin" ];

  # mkDefault so this module is self-sufficient on a hypothetical host that
  # loads base but not the desktop module (which also sets 25.05).
  home.stateVersion = lib.mkDefault "25.05";
}
