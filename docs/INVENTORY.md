# Migration Inventory

> **Note:** the bulk of this file is the *migration parity checklist* (old
> maudiblue/MyLinux setup → NixOS). The separate **Linux asset register** at the
> bottom is the compliance artifact required by the Linux workstation security
> policy §4.1 — see [compliance/linux-workstation-policy.md](compliance/linux-workstation-policy.md).

Everything the old setup (maudiblue image + MyLinux dotfiles) provides, with
the ticket responsible for migrating it. This doubles as the **parity
checklist for Ticket 17** — before archiving, every row must be either
*migrated* or *consciously dropped* (with the decision recorded in
[DECISIONS.md](DECISIONS.md)).

Status legend: `open` → `migrated` / `dropped`.

## 1. maudiblue — system packages (rpm-ostree / dnf layered)

| Package | Purpose | Target | Ticket | Status |
|---|---|---|---|---|
| fish | login shell | `programs.fish` + user shell | 03/06 | migrated |
| fastfetch | system info | home package + config port | 06 | migrated |
| wlogout | logout menu | hyprland desktop module | 04 | migrated |
| NetworkManager-tui | network TUI | NetworkManager (nmtui included) | 03 | migrated |
| waydroid | Android container | `virtualisation.waydroid` (keep? ask) | 16 | open |
| virt-manager, libvirt, qemu-kvm, virt-viewer | VMs | `virtualisation.libvirtd` module | 09 | open |
| lxqt-policykit | polkit agent | hyprpolkitagent instead (DECISIONS 018) | 04 | migrated |
| swaylock | lock screen | desktop module (swaylock-effects) | 04 | migrated |
| podman-compose | containers | dev module (podman + compose) | 08 | open |
| wireguard-tools | VPN | base + secrets for configs | 03/12 | migrated |
| bat, fd-find, ripgrep, fzf, tree, btop | CLI tools | home-manager (moved out of base, DECISIONS 013) | 06 | migrated |
| neovim, python3-neovim | editor | neovim module | 07 | open |
| swaybg, swayidle | wallpaper / idle | desktop module | 04 | migrated |
| papirus-icon-theme | icons | theming module | 05 | open |

## 2. maudiblue — flatpaks

| App | Target | Ticket | Status |
|---|---|---|---|
| Zen Browser (`app.zen_browser.zen`) | `0xc000022070/zen-browser-flake` twilight (DECISIONS 030) | 10 | migrated |
| Spotify (`com.spotify.Client`) | `pkgs.spotify` unfree (DECISIONS 029) | 10 | migrated |
| Flatseal (`com.github.tchx84.Flatseal`) | dropped — no flatpak on NixOS (DECISIONS 031/032) | 10 | dropped |
| Warehouse (`io.github.flattool.Warehouse`) | dropped — no flatpak on NixOS (DECISIONS 031/032) | 10 | dropped |

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
| `hypr/` | Hyprland + scripts | HM hyprland module + `pkgs/` scripts | 04 | migrated |
| `waybar/` | status bar | HM module | 04 | migrated |
| `dunst/` | notifications | HM module (dir was empty; shipped defaults) | 04 | migrated |
| `rofi/` | launcher | HM module | 04 | migrated |
| `wlogout/` | logout menu | HM module (text labels, no PNG icons) | 04 | migrated |
| `kitty/` | terminal | HM module (`programs.kitty`; colours via stylix) | 06 | migrated |
| `fish/` | shell | `programs.fish` | 06 | migrated |
| `fastfetch/` | system info | HM module (`programs.fastfetch`) | 06 | migrated |
| `lazygit/` | git TUI | HM module (config vendored verbatim) | 06 | migrated |
| `nvim/` | editor (~40 lazy.nvim plugins) | keep config, nix-provided tools | 07 | open |
| `matugen/` | theming templates | theming module (matugen vs stylix) | 05 | open |
| `gtk-3.0/`, `gtk-4.0/` | GTK theming | theming module | 05 | open |
| `Kvantum/`, `qt5ct/`, `qt6ct/` | Qt theming | theming module | 05 | open |
| `claude/` | Claude Code settings/hooks/commands | HM dev module (file-level links, never whole `~/.claude`) | 08 | open |

## 6. MyLinux — setup.sh installs (outside symlinks)

| Item | Current mechanism | Target | Ticket | Status |
|---|---|---|---|---|
| toolbox container `dev-tools` | toolbox + dnf (cargo, fish) | **obsolete** — nix packages/devshells | 08 | open |
| eza | cargo install (toolbox) | nixpkgs | 06 | migrated |
| matugen | cargo install (toolbox) | nixpkgs | 05 | open |
| cargo-nextest, bacon | cargo install (toolbox) | nixpkgs | 08 | open |
| hyprshot | git clone → `~/.local/bin` | nixpkgs | 04 | migrated |
| fisher + tide prompt | interactive fish install | **dropped** — starship instead (DECISIONS 023) | 06 | dropped |
| nvm / node | fisher plugin + nvm | nix per-project or global node | 08 | open |
| fish as default shell | `chsh` | `users.users.maudi.shell = pkgs.fish` | 03 | migrated |

## 7. MyLinux — runtime state & generated files (need writable-path design)

| Item | Problem | Ticket | Status |
|---|---|---|---|
| `hypr/cache/current_wallpaper.png` | cache in `~/.config`; hardcoded path in hyprland.conf + scripts | 05 | open |
| matugen-generated files (kitty/waybar/dunst/rofi/hypr/swaylock colors) | written into config dir at runtime — clashes with read-only HM symlinks | 05 | open |
| `monitor.conf` / `workspace.conf` rewritten by `monitor-hotplug.sh` | runtime mutation of config dir | 04 | migrated (kanshi, DECISIONS 017) |
| `focus-mode-rules.conf` rewritten by `focus-mode.sh` | runtime mutation of config dir | 04 | migrated (`hyprctl keyword`, DECISIONS 020) |
| `~/.config/ml4w/settings/{focusmode,gamemode}-enabled` | state in config dir, dir not in repo | 04 | migrated (`$XDG_STATE_HOME/desktop-nix`, DECISIONS 020) |

## 8. Known issues in the old config (resolve in "Ask when starting")

| Issue | Where | Ticket |
|---|---|---|
| `matugen/templates/*.tmpl` duplicated as inline bash in `apply_matugen.sh` — templates are dead code | MyLinux | 05 |
| Unused `$SCRIPTS` variable | `hypr/conf/keybindings/default.conf` | 04 |
| `swaybg/` symlinked by setup.sh but directory doesn't exist | MyLinux setup.sh | 04 |
| Hardcoded wallpaper/home paths in hyprland.conf, apply_matugen.sh, generated swaylock config | MyLinux | 05 |
| Hard kill/restart reload pattern (`pkill dunst; dunst &`) | apply_matugen.sh | 05 |
| firstboot.sh ignores failures (`|| true`), hardcoded repo URL | maudiblue | 03 |
| Tide prompt state in universal variables (not declarative) — resolved: replaced by starship (DECISIONS 023) | fish | 06 |

## Linux asset register (policy §4.1)

Compliance register required by the Linux workstation security policy §4.1.
Keep one row per company Linux device; update on hardware change, distro upgrade,
and at offboarding (§4.8). The "Hardening status" baseline is enforced in code
(DECISIONS 037/039) and verified by `nix flake check`; serial numbers and the
last manual-update date are filled in operationally (a master copy may also live
in the company Confluence table).

| Device type | Serial | User | Distro & version | Encryption | Firewall / hardening | Last updates |
|---|---|---|---|---|---|---|
| Laptop (work) | _TBD_ | maudi | NixOS (nixos-unstable) | LUKS2 full-disk | nftables default-deny, SSH off, root locked, auditd, sudo logging | auto-daily (auto-upgrade) |

