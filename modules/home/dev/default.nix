# Global language toolchains (daily drivers + the neovim LSP/treesitter stack);
# everything pinned goes in per-project devShells via direnv/nix-direnv.
{ pkgs, ... }:
{
  imports = [ ./claude.nix ];

  home.packages = with pkgs; [
    # Rust
    cargo
    rustc
    rustfmt
    clippy
    cargo-nextest
    bacon # background cargo check/clippy/test watcher

    # Go
    go

    # Node
    nodejs

    # Python
    python3
    uv

    # C toolchain
    gcc
    gnumake

    # Git tooling
    git-spice # `gs` — stacked-PR workflow
    gh

    claude-code
  ];

  # Per-project devShells load automatically on `cd` (fish integration is
  # wired because programs.fish is enabled).
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
