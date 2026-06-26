# cli

Per-user shell & CLI environment — imported on every host (including the headless
home-server, which gets the same shell and nothing else).

| File           | Configures                                                      |
|----------------|----------------------------------------------------------------|
| `fish.nix`     | fish shell + aliases (ported from the old dotfiles).           |
| `kitty.nix`    | kitty terminal.                                                |
| `fastfetch.nix`| fastfetch system info.                                         |
| `lazygit.nix`  | lazygit (delta as the diff pager).                             |
| `git.nix`      | git identity (Daniel Mauderer) + config, delta pager.          |

`default.nix` also adds the CLI tools (eza, bat, fd, ripgrep, fzf, tree, btop,
delta), the starship prompt (stylix-themed), zoxide fish integration, the
ssh-agent service, the declarative `~/.ssh/config` (GitHub → `~/.ssh/id_ed25519`,
keys auto-added to the agent), and sets `EDITOR=nvim`.

SSH private keys are per-host machine-local state (not in the repo). Bootstrap a
new host once: `ssh-keygen -t ed25519` then `gh ssh-key add ~/.ssh/id_ed25519.pub`.
