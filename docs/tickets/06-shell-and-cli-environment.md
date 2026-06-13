# 06 — Shell & CLI environment

- **Status:** migrated
- **Depends on:** 03
- **Machines:** all

## Goal

The fish environment fully via home-manager — config, aliases, functions,
prompt, and the CLI tools they depend on — replacing both the MyLinux
symlinks and the imperative installs from `setup.sh` (fisher, toolbox cargo
installs). Also ports the small standalone tool configs: kitty, fastfetch,
lazygit.

## Sub-tasks

- [x] `programs.fish` with content from `fish/config.fish`, `aliases.fish`,
      `functions.fish` (mkcd, extract, killf, gst, …) →
      `modules/home/cli/fish.nix`
- [x] Audit aliases for NixOS-isms: `tb`/`tbr` removed; `docker`→`podman`
      kept (dormant until Ticket 08); `update` is now
      `sudo nixos-rebuild switch --flake ~/desktop-nix`; the cargo/`gs`
      aliases stay dormant until Ticket 08
- [x] Prompt: **starship** (`programs.starship`), not tide — declarative and
      stylix-themed, so no `tide configure` / universal-var dependence
      (DECISIONS 023)
- [x] CLI tools as `home.packages`: `eza zoxide bat fd ripgrep fzf tree btop
      fastfetch delta` (zoxide via `programs.zoxide` for the fish hook) →
      `modules/home/cli/default.nix`
- [x] kitty: ported to `programs.kitty` (colours/font owned by stylix, old
      `include colors.conf` dropped; opacity via `stylix.opacity.terminal`)
- [x] fastfetch: ported `config.jsonc` → `programs.fastfetch.settings`
- [x] lazygit: `programs.lazygit` + vendored `config.yml`
- [x] Node/nvm: the fisher nvm plugin + `load_nvm` removed; node handed off
      to Ticket 08
- [x] Retire `setup.sh` symlink + fisher logic (documented in INVENTORY.md
      §5/§6)

## Testing

- [x] Baseline: extended `baseAssertions` (fish + starship enabled) and the
      `test-base-system` nixosTest (configs rendered, aliases/functions
      resolve, CLI tools on PATH) — runs in `nix flake check`
- [x] `nixosTest`: `fish -ic` smoke tests — `type ls` → eza, `type cat` →
      bat, `mkcd`/`gst` defined, `fish -ic true` exits cleanly
- [x] Prompt renders declaratively on a fresh home: starship binary present,
      `functions -q starship`, and tide is asserted absent (no universal-var
      setup needed)
- [x] kitty config rendered (`~/.config/kitty/kitty.conf`); full render test
      on hardware in Tickets 13–15

## Open questions

- [x] Prompt — resolved: **starship**, not tide/fisher (DECISIONS 023).
- [x] flatpak aliases — resolved: **dropped** until Ticket 10 decides flatpak.
- [x] eza/bat/fd home — resolved: home-manager only (base never shipped them,
      DECISIONS 013).

## Ask when starting

- Full declarative management confirmed: fisher/tide retired, no self-update
  flow; the prompt is starship.
- toolbox/cargo-path aliases confirmed for cleanup: `tb`/`tbr` removed; the
  cargo and `gs` aliases are kept but dormant until their tools land in
  Ticket 08.
