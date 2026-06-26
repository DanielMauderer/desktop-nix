# git identity & config (home-manager). Without this, git falls back to the
# autodetected `maudi@<host>.(none)` and refuses to commit — which is what broke
# committing from lazygit. `programs.git` writes a declarative ~/.gitconfig.
#
# delta is already installed (../cli/default.nix) as the lazygit pager; wiring it
# in here makes plain `git diff`/`git log -p` use it too.
{ pkgs, ... }:
{
  programs.git = {
    enable = true;
    package = pkgs.git;

    delta.enable = true;

    settings = {
      user.name = "Daniel Mauderer";
      user.email = "daniel090798@gmail.com";
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
  };
}
