# jj (jujutsu) as an alternative front-end to the same git repos — colocated
# (`jj git init --colocate`), so git.nix's config still applies to the backend.
#
# The config below is declarative: HM links ~/.config/jj/config.toml into the
# store, so `jj config set --user` fails with a read-only file. Edit this module
# instead; for throwaway local overrides drop a file in ~/.config/jj/conf.d/,
# which jj merges on top of config.toml.
{ pkgs, ... }:
{
  programs.jujutsu = {
    enable = true;
    package = pkgs.jujutsu;

    settings = {
      # Duplicated from git.nix — jj reads its own identity, not git's.
      user = {
        name = "Daniel Mauderer";
        email = "daniel090798@gmail.com";
      };

      ui = {
        # Bare `jj` errors out otherwise.
        default-command = "log";
        editor = "nvim";
        # delta as the diff pager, matching git.nix/lazygit; needs git-format
        # diffs to colourise.
        diff-formatter = ":git";
        pager = "delta";
      };

      git = {
        # Off by default upstream: creates a local bookmark for every remote
        # branch on fetch, which on a busy shared remote means bookmark
        # conflicts to resolve. Worth it here — a stack fetched from a PR shows
        # up ready to rebase instead of needing `jj bookmark track` per branch.
        # Flip to false if fetch starts reporting conflicted bookmarks.
        auto-local-bookmark = true;
      };

      aliases = {
        # Rebase the whole current branch onto the new trunk after a fetch.
        sync = [
          "rebase"
          "-d"
          "trunk()"
        ];
        # Push the bookmarks in the current stack only. `--all` would also push
        # every unrelated bookmark left over in the repo.
        ps = [
          "git"
          "push"
          "-r"
          "::@"
        ];
      };
    };
  };

  # TUI: jjui handles stacked branches better than lazyjj (bookmark move,
  # interactive rebase/squash targets, oplog undo).
  home.packages = [ pkgs.jjui ];
}
