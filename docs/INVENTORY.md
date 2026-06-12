# Migration Inventory

Everything the old setup (maudiblue image + MyLinux dotfiles) provides, with
the ticket responsible for migrating it. This doubles as the **parity
checklist for Ticket 17** — before archiving, every row must be either
*migrated* or *consciously dropped* (with the decision recorded in
[DECISIONS.md](DECISIONS.md)).

Status legend: `open` → `migrated` / `dropped`.

## 1. maudiblue — system packages (rpm-ostree / dnf layered)

| Package | Purpose | Target | Ticket | Status |
|---|---|---|---|---|
| fish | login shell | `programs.fish` + user shell | 03/06 | open |
| fastfetch | system info | home package + config port | 06 | open |
| wlogout | logout menu | hyprland desktop module | 04 | open |
| NetworkManager-tui | network TUI | NetworkManager (nmtui included) | 03 | migrated |
| waydroid | Android container | `virtualisation.waydroid` (keep? ask) | 16 | open |
| virt-manager, libvirt, qemu-kvm, virt-viewer | VMs | `virtualisation.libvirtd` module | 09 | open |
| lxqt-policykit | polkit agent | desktop module (or alternative agent) | 04 | open |
| swaylock | lock screen | desktop module | 04 | open |
| podman-compose | containers | dev module (podman + compose) | 08 | open |
| wireguard-tools | VPN | base + secrets for configs | 03/12 | migrated |
| bat, fd-find, ripgrep, fzf, tree, btop | CLI tools | home-manager (moved out of base, DECISIONS 013) | 06 | open |
| neovim, python3-neovim | editor | neovim module | 07 | open |
| swaybg, swayidle | wallpaper / idle | desktop module | 04 | open |
| papirus-icon-theme | icons | theming module | 05 | open |

## 2. maudiblue — flatpaks

| App | Target | Ticket | Status |
|---|---|---|---|
| Zen Browser (`app.zen_browser.zen`) | nixpkgs / community flake / nix-flatpak (decide) | 10 | open |
| Spotify (`com.spotify.Client`) | nixpkgs unfree / nix-flatpak (decide) | 10 | open |
| Flatseal (`com.github.tchx84.Flatseal`) | only if flatpak stays | 10 | open |
| Warehouse (`io.github.flattool.Warehouse`) | only if flatpak stays | 10 | open |

## 3. maudiblue — fonts

| Fonts | Target | Ticket | Status |
|---|---|---|---|
| Nerd Fonts: FiraCode, Hack, SourceCodePro, Terminus, JetBrainsMono, SymbolsOnly | `fonts.packages` (`nerd-fonts.*`) | 03 | migrated |
| Google Fonts: Roboto, Open Sans | `fonts.packages` | 03 | migrated |

## 4. maudiblue — services & mechanisms

| Item | Target | Ticket | Status |
|---|---|---|---|
| firstboot.service (clones MyLinux, runs setup.sh) | **dropped** — config is declarative (DECISIONS 014) | 03 | dropped |
| rpm-ostreed-automatic.timer (staged auto-updates) | `system.autoUpgrade` from main (DECISIONS 011) | 03 | migrated |
| homebrew/linuxbrew module | **dropped** — nixpkgs replaces it (DECISIONS 014); tool parity → 06/08/17 | 03 | dropped |
| libvirtd.service enabled | virtualisation module | 09 | open |
| BlueBuild GitHub Action (daily image build) | disabled at archive time | 17 | open |
| cosign image signing | n/a on NixOS (flake.lock + git history instead) | 17 | open |

## 5. MyLinux — config directories (17, symlinked by setup.sh)

| Dir | App | Target | Ticket | Status |
|---|---|---|---|---|
| `hypr/` | Hyprland + scripts | HM hyprland module + `pkgs/` scripts | 04 | open |
| `waybar/` | status bar | HM module | 04 | open |
| `dunst/` | notifications | HM module | 04 | open |
| `rofi/` | launcher | HM module | 04 | open |
| `wlogout/` | logout menu | HM module | 04 | open |
| `kitty/` | terminal | HM module | 06 | open |
| `fish/` | shell | `programs.fish` | 06 | open |
| `fastfetch/` | system info | HM module | 06 | open |
| `lazygit/` | git TUI | HM module | 06 | open |
| `nvim/` | editor (~40 lazy.nvim plugins) | keep config, nix-provided tools | 07 | open |
| `matugen/` | theming templates | theming module (matugen vs stylix) | 05 | open |
| `gtk-3.0/`, `gtk-4.0/` | GTK theming | theming module | 05 | open |
| `Kvantum/`, `qt5ct/`, `qt6ct/` | Qt theming | theming module | 05 | open |
| `claude/` | Claude Code settings/hooks/commands | HM dev module (file-level links, never whole `~/.claude`) | 08 | open |

## 6. MyLinux — setup.sh installs (outside symlinks)

| Item | Current mechanism | Target | Ticket | Status |
|---|---|---|---|---|
| toolbox container `dev-tools` | toolbox + dnf (cargo, fish) | **obsolete** — nix packages/devshells | 08 | open |
| eza | cargo install (toolbox) | nixpkgs | 06 | open |
| matugen | cargo install (toolbox) | nixpkgs | 05 | open |
| cargo-nextest, bacon | cargo install (toolbox) | nixpkgs | 08 | open |
| hyprshot | git clone → `~/.local/bin` | nixpkgs | 04 | open |
| fisher + tide prompt | interactive fish install | `fishPlugins.tide` or HM-managed fisher | 06 | open |
| nvm / node | fisher plugin + nvm | nix per-project or global node | 08 | open |
| fish as default shell | `chsh` | `users.users.maudi.shell = pkgs.fish` | 03 | migrated |

## 7. MyLinux — runtime state & generated files (need writable-path design)

| Item | Problem | Ticket | Status |
|---|---|---|---|
| `hypr/cache/current_wallpaper.png` | cache in `~/.config`; hardcoded path in hyprland.conf + scripts | 05 | open |
| matugen-generated files (kitty/waybar/dunst/rofi/hypr/swaylock colors) | written into config dir at runtime — clashes with read-only HM symlinks | 05 | open |
| `monitor.conf` / `workspace.conf` rewritten by `monitor-hotplug.sh` | runtime mutation of config dir | 04 | open |
| `focus-mode-rules.conf` rewritten by `focus-mode.sh` | runtime mutation of config dir | 04 | open |
| `~/.config/ml4w/settings/{focusmode,gamemode}-enabled` | state in config dir, dir not in repo | 04 | open |

## 8. Known issues in the old config (resolve in "Ask when starting")

| Issue | Where | Ticket |
|---|---|---|
| `matugen/templates/*.tmpl` duplicated as inline bash in `apply_matugen.sh` — templates are dead code | MyLinux | 05 |
| Unused `$SCRIPTS` variable | `hypr/conf/keybindings/default.conf` | 04 |
| `swaybg/` symlinked by setup.sh but directory doesn't exist | MyLinux setup.sh | 04 |
| Hardcoded wallpaper/home paths in hyprland.conf, apply_matugen.sh, generated swaylock config | MyLinux | 05 |
| Hard kill/restart reload pattern (`pkill dunst; dunst &`) | apply_matugen.sh | 05 |
| firstboot.sh ignores failures (`|| true`), hardcoded repo URL | maudiblue | 03 |
| Tide prompt state in universal variables (not declarative) | fish | 06 |
