{ pkgs, ... }:
{
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };

  programs.git = {
    enable = true;
    package = pkgs.git;
    lfs.enable = true;

    settings = {
      user.name = "Daniel Mauderer";
      user.email = "daniel090798@gmail.com";
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
  };
}
