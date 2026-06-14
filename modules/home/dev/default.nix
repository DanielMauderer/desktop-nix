# Dev environment (home-manager) — Ticket 08, Machines: all (wired in base).
#
# Replaces the Silverblue `dev-tools` toolbox container with nix-native tooling.
# Strategy (DECISIONS 027): a thin set of global language toolchains (the daily
# drivers, also needed by the neovim LSP/treesitter stack) plus per-project
# `devShells` via direnv/nix-direnv for everything pinned. rustup is an
# anti-pattern on NixOS, so Rust comes straight from nixpkgs.
#
# This module *owns the language toolchains*; the neovim module (Ticket 07) keeps
# only editor-specific tooling (LSP servers, formatters, DAP adapters). The two
# always load together via modules/nixos/base/home.nix.
{ pkgs, ... }:
{
  imports = [ ./claude.nix ];

  home.packages = with pkgs; [
    # ── Rust toolchain (nixpkgs stable — DECISIONS 027) ───────────────────────
    cargo
    rustc
    rustfmt # also used by the Claude rustfmt PostToolUse hook + conform.nvim
    clippy # `ck` alias, /clippy command, the Claude clippy Stop hook
    cargo-nextest # `ct` alias, /nextest command (was a toolbox `cargo install`)
    bacon # `cw` alias — background cargo check/clippy/test watcher (was toolbox)

    # ── Go ────────────────────────────────────────────────────────────────────
    go

    # ── Node (single global LTS — replaces nvm/`load_nvm`) ─────────────────────
    nodejs # npm/npx for the nf/nl/nt/nx aliases; nvim treesitter + js-debug

    # ── Python (venv is stdlib → venv-selector workflow) ──────────────────────
    python3
    uv # fast project venvs / installs

    # ── C toolchain ───────────────────────────────────────────────────────────
    gcc
    gnumake

    # ── Git tooling (aliases dormant since Ticket 06) ─────────────────────────
    git-spice # `gs` alias — stacked-PR workflow
    gh # GitHub CLI — lazygit's PR commands
  ];

  # direnv + nix-direnv: per-project devShells load automatically on `cd`.
  # Fish integration is wired automatically because programs.fish is enabled
  # (modules/home/cli). nix-direnv adds fast, GC-pinned `use flake` caching.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
