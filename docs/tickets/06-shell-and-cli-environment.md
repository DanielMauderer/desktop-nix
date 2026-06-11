# 06 — Shell & CLI environment

- **Status:** open
- **Depends on:** 03
- **Machines:** all

## Goal

The fish environment fully via home-manager — config, aliases, functions,
prompt, and the CLI tools they depend on — replacing both the MyLinux
symlinks and the imperative installs from `setup.sh` (fisher, toolbox cargo
installs). Also ports the small standalone tool configs: kitty, fastfetch,
lazygit.

## Sub-tasks

- [ ] `programs.fish` with content from `fish/config.fish`, `aliases.fish`,
      `functions.fish` (mkcd, extract, killf, gst, …)
- [ ] Audit aliases for NixOS-isms: `tb`/`tbr` (toolbox) are obsolete —
      replace with devshell equivalents (Ticket 08); `docker`→`podman` stays;
      update-related aliases (`rpm-ostree upgrade`) → `nixos-rebuild` wrappers
- [ ] Prompt: tide via `fishPlugins.tide` (declarative) vs keep fisher
      imperative — decide; if tide: pin its settings declaratively instead of
      relying on `tide configure`'s universal variables
- [ ] CLI tools as `home.packages`: `eza` (was cargo/toolbox), `zoxide`,
      whatever `aliases.fish`/`functions.fish` reference — audit and list
- [ ] kitty: port `kitty.conf` (color include hook per Ticket 05)
- [ ] fastfetch: port `config.jsonc`
- [ ] lazygit: port config
- [ ] Node/nvm: the fisher nvm plugin goes away — decide global node vs
      per-project (hand off to Ticket 08)
- [ ] Retire `setup.sh` symlink + fisher logic (document in INVENTORY.md)

## Testing

- [ ] Baseline: flake check, linters, all host builds, CI green
- [ ] `nixosTest`: login as user in VM, run `fish -c` smoke tests — aliases
      resolve (`type ls` → eza, `type cat` → bat), custom functions defined,
      no startup errors/warnings on first launch
- [ ] Tide prompt renders without running `tide configure` (fresh-home test:
      VM has no pre-existing universal variables)
- [ ] kitty starts with the config (config-parse check; full render test on
      hardware)

## Open questions

- [ ] tide via nixpkgs `fishPlugins.tide` vs fisher — and how to make tide's
      settings (normally universal vars written by `tide configure`)
      declarative and reproducible on a fresh machine?
- [ ] Keep the `fpi`-style flatpak aliases (depends on Ticket 10's outcome)?
- [ ] eza/bat/fd exist both as maudiblue system packages (Ticket 03) and
      user tools — single home for them? (Recommendation: HM here.)

## Ask when starting

- `fish_plugins` lists fisher+tide but the generated functions are gitignored
  and installed interactively by setup.sh (not idempotent) — confirm full
  declarative management is wanted (no fisher self-update flow anymore).
- Some aliases reference toolbox paths (`~/.cargo/bin` inside dev-tools) that
  won't exist — confirm cleanup as part of this ticket.
