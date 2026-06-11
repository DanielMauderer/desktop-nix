# 03 — Base system module

- **Status:** open
- **Depends on:** 01, 02
- **Machines:** all

## Goal

`modules/nixos/base`: everything every host shares — boot, locale, user,
networking, audio, nix settings, base CLI tools, and fonts. Replaces the
package layering from maudiblue's `recipe.yml` (see
[INVENTORY.md](../INVENTORY.md) §1, §3, §4).

## Sub-tasks

- [ ] Boot: systemd-boot + EFI (matches current machines; verify during host tickets)
- [ ] Locale, timezone, console keymap
- [ ] User account, `users.users.<user>.shell = pkgs.fish` (replaces `chsh` in setup.sh),
      groups (wheel, and later libvirtd/gamemode via their modules)
- [ ] Networking: NetworkManager (`nmtui` is included — replaces `NetworkManager-tui` layer)
- [ ] Audio: pipewire (+ wireplumber), bluetooth (`hardware.bluetooth`, blueman?)
- [ ] Nix settings: flakes enabled, `nix.gc` automatic, `nix.optimise`,
      trusted users, the caches decided in Ticket 02
- [ ] Base CLI packages from maudiblue: `bat`, `fd`, `ripgrep`, `fzf`, `tree`,
      `btop`, `wireguard-tools` (fastfetch/eza/lazygit live in Ticket 06)
- [ ] Fonts: `nerd-fonts.{fira-code,hack,sauce-code-pro,terminess-ttf,jetbrains-mono,symbols-only}`,
      `roboto`, `open-sans`; fontconfig defaults
- [ ] Update strategy: decide replacement for rpm-ostreed staged auto-updates
      (`system.autoUpgrade` with a flake ref vs manual rebuilds) — record in DECISIONS.md
- [ ] Confirm drops: homebrew module (replaced by nixpkgs), firstboot
      dotfiles-clone service (config is now declarative)

## Testing

- [ ] Baseline: flake check, linters, all host builds, CI green
- [ ] `nixosTest`: VM boots, user exists with fish as login shell,
      NetworkManager unit active, pipewire socket present
- [ ] `nixosTest`: `fc-list` contains JetBrainsMono Nerd Font (fonts actually land)
- [ ] Manual (later, on pilot hardware): audio out, bluetooth pairing, wifi via nmtui

## Open questions

- [ ] `system.autoUpgrade` (matches old staged-update behavior) vs manual
      `nixos-rebuild` only? If auto: from the git repo's main branch?
- [ ] Bluetooth GUI: blueman, or waybar module only?
- [ ] Keep `tree`/`fzf` as system packages or move all CLI tools to
      home-manager (Ticket 06)? Recommendation: user-facing CLI → HM, keep the
      system set minimal.

## Ask when starting

- maudiblue's `firstboot.sh` clones MyLinux over HTTPS with `|| true` (failures
  ignored) and a hardcoded URL — obsolete on NixOS, confirm it has no other
  job worth keeping (it only bootstrapped dotfiles).
- Homebrew was enabled with auto-update/auto-upgrade timers — confirm nothing
  was actually installed via brew that needs a nixpkgs equivalent.
