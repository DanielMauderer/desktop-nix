# 03 — Base system module

- **Status:** done
- **Depends on:** 01, 02
- **Machines:** all

## Goal

`modules/nixos/base`: everything every host shares — boot, locale, user,
networking, audio, nix settings, base CLI tools, and fonts. Replaces the
package layering from maudiblue's `recipe.yml` (see
[INVENTORY.md](../INVENTORY.md) §1, §3, §4).

## Sub-tasks

- [x] Boot: systemd-boot + EFI (`base/boot.nix`; centralised out of host stubs)
- [x] Locale, timezone, console keymap (`base/locale.nix`, German defaults via mkDefault)
- [x] User account, `users.users.maudi.shell = pkgs.fish` (replaces `chsh` in setup.sh),
      groups (wheel, networkmanager, dialout; libvirtd/gamemode later via their modules)
- [x] Networking: NetworkManager (`nmtui` is included — replaces `NetworkManager-tui` layer)
- [x] Audio: pipewire (+ wireplumber); bluetooth stack only — GUI deferred to Ticket 04 (DECISIONS 012)
- [x] Nix settings: flakes enabled, `nix.gc` automatic, `nix.optimise`, trusted users
      (per-feature binary caches added by their own modules, e.g. chaotic on desktop)
- [x] Base CLI: minimal system set only (`wireguard-tools` + recovery essentials);
      user-facing CLI moved to home-manager / Ticket 06 (DECISIONS 013)
- [x] Fonts: `nerd-fonts.{fira-code,hack,sauce-code-pro,terminess-ttf,jetbrains-mono,symbols-only}`,
      `roboto`, `open-sans`; fontconfig defaultFonts
- [x] Update strategy: `system.autoUpgrade` from this flake's `main` (DECISIONS 011)
- [x] Confirm drops: homebrew module + firstboot dotfiles-clone service (DECISIONS 014).
      Brew → nixpkgs tool-parity mapping tracked for Tickets 06/08/17 (awaiting `brew leaves`)

## Testing

- [x] Baseline: flake eval + linters clean locally, all three host toplevels build;
      CI runs flake check + host builds on the branch
- [x] `nixosTest` (`checks.test-base-system`): VM boots, user exists with fish as
      login shell, NetworkManager active, pipewire socket unit installed
- [x] `nixosTest`: `fc-list` contains JetBrainsMono Nerd Font (fonts actually land)
- [ ] Manual (later, on pilot hardware — Ticket 13): audio out, bluetooth pairing, wifi via nmtui

## Open questions

- [x] `system.autoUpgrade` vs manual → **autoUpgrade from this flake's `main`**
      (DECISIONS 011).
- [x] Bluetooth GUI → **stack only in base; GUI deferred to Ticket 04**
      (DECISIONS 012).
- [x] CLI tools in base vs home-manager → **minimal base, user CLI in HM**
      (DECISIONS 013).

## Ask when starting

- [x] `firstboot.sh` (clones MyLinux + setup.sh) → **dropped**, obsolete on
      NixOS (DECISIONS 014).
- [x] Homebrew → **dropped** (DECISIONS 014). Redundant on NixOS — it was a
      Fedora-atomic workaround for immutability. Concrete brew→nixpkgs tool
      mapping is a parity item awaiting the user's `brew leaves` output,
      tracked for Tickets 06/08/17.
