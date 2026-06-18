# cli

Per-user shell & CLI environment — imported on every host (including the headless
home-server, which gets the same shell and nothing else).

| File           | Configures                                                      |
|----------------|----------------------------------------------------------------|
| `fish.nix`     | fish shell + aliases (ported from the old dotfiles).           |
| `kitty.nix`    | kitty terminal.                                                |
| `fastfetch.nix`| fastfetch system info.                                         |
| `lazygit.nix`  | lazygit (delta as the diff pager).                             |

`default.nix` also adds the CLI tools (eza, bat, fd, ripgrep, fzf, tree, btop,
delta), the starship prompt (stylix-themed), zoxide fish integration, the
ssh-agent service, and sets `EDITOR=nvim`.
