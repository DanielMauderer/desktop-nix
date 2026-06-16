# Architecture Decisions

ADR-lite log. One entry per decision: context, decision, consequences.
Add an entry whenever a ticket resolves one of its "Open questions".

---

## 001 — Plain flake, no flake-parts (2026-06-11)

**Context:** The repo manages 3 hosts with home-manager. flake-parts adds a
module system for flake outputs, which pays off with many per-system outputs
and complex output wiring.

**Decision:** Use a plain `flake.nix` plus a small `lib/mkHost.nix` helper.

**Consequences:** Less abstraction to learn while simultaneously learning
NixOS. Revisit if `checks`/`devShells` boilerplate grows — migrating to
flake-parts later is mechanical.

---

## 002 — home-manager as a NixOS module, not standalone (2026-06-11)

**Context:** home-manager can run standalone (`home-manager switch`) or as a
NixOS module (one `nixos-rebuild switch` for system + home).

**Decision:** Use home-manager as a NixOS module.

**Consequences:** Host and home configuration stay atomic — no version skew
between system and home generations; a single rollback covers both. Trade-off:
home changes require a system rebuild (acceptable: single-user machines).

---

## 003 — CachyOS kernel via chaotic-cx/nyx (2026-06-11)

**Context:** The desktop host wants the CachyOS kernel for gaming performance.
On NixOS this is packaged by the [chaotic-cx/nyx](https://github.com/chaotic-cx/nyx)
flake (`linuxPackages_cachyos`, `scx` schedulers) with a binary cache.

**Decision:** Add chaotic-nyx as a flake input, enabled only on the `desktop`
host. Use its binary cache to avoid local kernel compiles (details in Ticket 11).

**Consequences:** Desktop kernel updates follow chaotic-nyx's cadence; CI must
trust the chaotic cache or skip the kernel build.

---

## 005 — nixpkgs channel: nixos-unstable (2026-06-11)

**Context:** Ticket 01 required choosing between `nixos-unstable` and a stable
release for the nixpkgs input.

**Decision:** Use `nixos-unstable`. Hyprland and chaotic-nyx move fast and
both track unstable; using a stable branch would require constant back-porting
or overlay pinning.

**Consequences:** System is on rolling nixpkgs; occasional evaluation breakage
is possible. Mitigated by CI catching broken builds before they reach hardware.

---

## 006 — Hyprland from the Hyprland flake, not nixpkgs (2026-06-11)

**Context:** Ticket 04 (Hyprland desktop stack) needs Hyprland. It is also
packaged in nixpkgs, but the upstream flake ships newer commits and the
Hyprland project recommends it.

**Decision:** Add `github:hyprwm/Hyprland` as a flake input, following
nixpkgs. The input was added in Ticket 01 so the lock file is established
early; the module wiring happens in Ticket 04.

**Consequences:** Hyprland version follows the upstream flake, independent of
the nixpkgs Hyprland package. Adds one extra flake input to track.

---

## 007 — Username: `maudi` on all machines (2026-06-11)

**Context:** All three machines are personal, single-user.

**Decision:** The primary user account is `maudi` on all three machines.

**Consequences:** Modules can use a shared username constant rather than
per-host overrides. If this ever changes, one value to update.

---

## 008 — CI binary cache: magic-nix-cache (2026-06-11)

**Context:** Ticket 02 required choosing a binary cache strategy for CI to
avoid rebuilding the world on every run.

**Decision:** Use `DeterminateSystems/magic-nix-cache-action`. Zero-config,
integrates with GitHub Actions cache automatically, no account or token needed.

**Consequences:** Cache is scoped to the GitHub Actions cache of the repo
(7 GB limit, evicted after 7 days of inactivity). Works out-of-the-box on
push/PR. If cache requirements outgrow the limit, revisit cachix.

---

## 009 — Pre-commit hooks: CI only (2026-06-11)

**Context:** Ticket 02 considered whether to enforce lint/format checks via
git-hooks.nix locally in addition to CI.

**Decision:** CI only. No local pre-commit hook setup required.

**Consequences:** Developers can commit un-linted code locally; CI catches
it and the PR stays red until fixed. Reduces friction for work-in-progress
commits. The `devShell` already ships `statix`, `deadnix`, and `nixfmt-rfc-style`
so manual checks are one command away.

---

## 010 — nixosTest coverage bar: assert multi-user.target (2026-06-11)

**Context:** Ticket 02 required deciding how far to take `nixosTest` for
graphical stacks (Hyprland can start headless in a VM).

**Decision:** The baseline nixosTest asserts `multi-user.target` reached.
Later tickets extend this pattern (e.g. assert Hyprland session unit active,
libvirtd active) by copying the template in `checks.x86_64-linux`.

**Consequences:** Boot-level regression is caught automatically from Ticket 02
onward. Graphical assertions are left to the relevant ticket (04 for Hyprland,
09 for libvirt) rather than being forced into the baseline.

---

## 011 — Update strategy: system.autoUpgrade from git main (2026-06-11)

> **Superseded in part:** the `weekly` cadence below became `daily` in
> [039](#039); the single shared `main` channel became a per-host split
> (pilot/desktop on `main`, work-laptop on a CI-gated `release` branch) in
> [042](#042); and the lock-bump that actually moves the fleet was automated in
> [043](#043). The "track a flake ref, no auto-reboot" core still holds.

**Context:** Ticket 03 had to replace maudiblue's `rpm-ostreed-automatic.timer`
staged auto-updates. Options were manual `nixos-rebuild` only, or
`system.autoUpgrade` pointed at a flake ref.

**Decision:** Enable `system.autoUpgrade` on every host, pulling
`github:DanielMauderer/desktop-nix` (the `main` branch) on a weekly timer with
`allowReboot = false`.

**Consequences:** Hosts track `main` automatically, closest to the old staged
behavior. Because nixpkgs is `nixos-unstable` (DECISIONS 005), an upstream
break could land via auto-upgrade — mitigated by CI gating `main` and by
no automatic reboots (kernel/initrd changes apply on the next manual reboot).
Switching a host to manual-only is a one-line `enable = false` override.

---

## 012 — Bluetooth: stack only in base, GUI deferred (2026-06-11)

**Context:** Ticket 03 asked whether the base module should ship a Bluetooth
GUI (blueman) or leave it to the bar/desktop layer.

**Decision:** base enables only `hardware.bluetooth` (the stack). Any GUI /
applet is the desktop module's job (Ticket 04, alongside waybar).

**Consequences:** Headless hosts (none today, but e.g. a future server) don't
pull a GTK pairing tool. The desktop ticket owns the pairing UX end-to-end.

---

## 013 — CLI tool placement: minimal base, user CLI in home-manager (2026-06-11)

**Context:** Ticket 03 listed `bat fd ripgrep fzf tree btop` as base CLI, but
its open question recommended pushing user-facing CLI into home-manager.

**Decision:** base keeps only system-level essentials (git, vim, wget, curl,
wireguard-tools, pciutils, usbutils). User-facing CLI tools move to
home-manager in Ticket 06.

**Consequences:** The system closure stays small; user CLI lives with the rest
of the user's environment and is per-user overridable. wireguard-tools stays
in base because VPN is a system concern (and pairs with secrets in Ticket 12).

---

## 014 — Drop homebrew and the firstboot dotfiles clone (2026-06-11)

**Context:** Ticket 03's "ask when starting" flagged maudiblue's
`firstboot.service` (clones MyLinux + runs setup.sh) and the homebrew module.
On Fedora atomic, homebrew was the pragmatic way to get host-level CLI tools
without rpm-ostree layering (reboots) or toolbox (poor device/host
integration, e.g. serial `tio`).

**Decision:** Drop both. firstboot is obsolete — configuration is now
declarative. homebrew is redundant on NixOS: `environment.systemPackages`,
home-manager packages, and `nix shell` cover everything brew did, with no
immutability workaround. Brew-installed tools migrate to nixpkgs in their
respective tickets (CLI → 06, dev → 08).

**Consequences:** No `/home/linuxbrew`, no brew auto-update timers. The
concrete brew formula → nixpkgs mapping is a parity item: the user supplies
`brew leaves` / `brew list --cask`, tracked against Tickets 06/08 and the
final parity sweep (Ticket 17).

---

## 004 — Migration order: private-laptop → work-laptop → desktop (2026-06-11)

**Context:** Three machines with different risk profiles.

**Decision:** Pilot on the private laptop (lowest risk), apply lessons, then
the work laptop, then the gaming desktop.

**Consequences:** Gaming/CachyOS stack (Ticket 11) is validated last on real
hardware, even though it can be developed and CI-built earlier.

---

## 015 — Greeter: greetd + tuigreet (2026-06-12)

**Context:** Ticket 04 needed a login manager to launch the Hyprland session.
Options were greetd+tuigreet, SDDM, or autologin.

**Decision:** Use `greetd` with `tuigreet`, launching `Hyprland` directly.

**Consequences:** A minimal, Wayland-native TUI greeter with no Qt/X
dependency. Themed via tuigreet flags rather than a GUI theme engine. If a
graphical greeter is ever wanted (e.g. fingerprint UX), SDDM is a drop-in swap
in `modules/nixos/desktop/greetd.nix`.

---

## 016 — Lock screen: swaylock + swayidle (2026-06-12)

**Context:** The old config mixed `swaylock`/`swayidle` (hyprland.conf
exec-once, SUPER+L) with `hyprlock`/`hypridle` (XF86Lock, power.sh, an unbound
waybar toggle). Two idle/lock stacks for one machine.

**Decision:** Standardise on `swaylock` (the `swaylock-effects` package, so the
matugen-generated config in Ticket 05 keeps its `image=`/`fade-in`/`grace`
options) driven by `swayidle`. `hyprlock`/`hypridle` and their scripts are
dropped.

**Consequences:** One idle/lock stack. swaylock's PAM service is enabled
system-side (`security.pam.services.swaylock`). Ticket 05 themes the lock
screen; Ticket 11's gamemode is unaffected.

---

## 017 — Monitor management: kanshi (2026-06-12)

**Context:** The old setup cycled monitor/workspace layouts by **rewriting**
`conf/monitor.conf` and `conf/workspace.conf` inside the config dir
(`monitor-hotplug.sh`, `switch_hypr_env.sh`) — incompatible with read-only
home-manager-managed config.

**Decision:** Use `kanshi`, which applies the first output profile whose
monitors are all connected. The old per-resolution `.conf` files become kanshi
profiles (desktop dual-head, work-laptop docked/undocked, laptop-internal).
Dock/undock is automatic; no keybind or file writes.

**Consequences:** `monitor-hotplug.sh`/`switch_hypr_env.sh` are dropped. Output
names/modes are lifted from the old configs and verified on hardware in Tickets
13–15, where per-host workspace→monitor assignment is also layered in.

---

## 018 — Polkit agent: hyprpolkitagent (2026-06-12)

**Context:** maudiblue shipped `lxqt-policykit`. Ticket 04 had to pick a polkit
authentication agent for the Hyprland session.

**Decision:** Use `hyprpolkitagent` (hyprwm), matching the upstream-flake
Hyprland stack. Started from the user session via `exec-once`.

**Consequences:** One fewer Qt/LXQt dependency; the agent tracks the Hyprland
project. `security.polkit.enable` is set system-side.

---

## 019 — Hyprland config form: native home-manager settings (2026-06-12)

**Context:** Ticket 04 could keep the old modular `hypr/conf/*.conf` files
verbatim (`xdg.configFile`) or translate them into
`wayland.windowManager.hyprland.settings`.

**Decision:** Translate to native home-manager settings. Window rules are
expressed in the unified `windowrule` string form; the colour variables used by
the gradient borders are static defaults that Ticket 05 replaces with matugen
output.

**Consequences:** The config is type-checked Nix and store-path references to
packaged scripts are exact. The trade-off is an up-front translation; the old
modular file layout is not preserved. `configType = "hyprlang"` is pinned (the
HM default flips to Lua at stateVersion 26.05).

---

## 020 — Desktop runtime state: $XDG_STATE_HOME/desktop-nix (2026-06-12)

**Context:** focus-mode and gamemode kept their on/off flags in
`~/.config/ml4w/settings/` — inside the (now read-only) HM config tree, under
the leftover ML4W namespace.

**Decision:** Move runtime flags to `$XDG_STATE_HOME/desktop-nix/`
(`~/.local/state/desktop-nix/`). focus-mode is additionally redesigned to apply
its workspace rule with `hyprctl keyword` instead of rewriting a tracked
`focus-mode-rules.conf`.

**Consequences:** No runtime writes into the HM-managed config dir. The `ml4w`
namespace is retired. Ticket 05's matugen wallpaper/colour cache will follow the
same writable-path pattern.

---

## 021 — Test layering: eval-level host assertions, VM only for runtime (2026-06-12)

**Context:** CI builds all three host toplevels and boots a VM test, but
nothing asserted the per-host deltas: chaotic only on desktop, kanshi monitor
profile ordering (`lib.mkBefore` docked/dual-head profiles vs the
`laptop-internal` fallback). Spinning up a VM per host just to check evaluated
config facts is wasteful. The format gate also lived only in CI
(`nix fmt . && git diff`), violating Ticket 02's "local == CI, no drift" goal.

**Decision:** Extend 010 with an explicit layering. Config *facts* (hostname,
user/shell, stateVersion, home-manager wiring, chaotic module presence, kanshi
profile order plus greps over the rendered `kanshi/config`) are asserted at
flake-check time via a `mkHostCheck` helper in `flake.nix` — a failed
assertion `throw`s during evaluation, naming every failed assertion for the
host. VM tests are reserved for behavior that needs a booted system
(`test-desktop` now also covers dunst/kanshi/swayidle service wiring, rofi,
wlogout, swaylock, kitty and the xdg portals). Formatting moves into the
`nixfmt-check` flake check and CI's separate fmt step is removed, so
`nix flake check -L` is the entire gate locally and in CI. No additional
linters (actionlint, standalone shellcheck) — Nix-only; raw scripts in
`pkgs/scripts/` are already shellchecked by `writeShellApplication`.

**Consequences:** Host deltas fail fast at eval time with named assertions —
no VM boot needed. `nixosConfigurations` is hoisted to a shared `hosts` let
binding so checks and outputs evaluate each host once. The trade-off is that
`nix flake check` now evaluates all three hosts even for unrelated checks.

---

## 022 — Theming: Stylix, not matugen (2026-06-13)

**Context:** Ticket 05's core decision. The old MyLinux pipeline ran
`matugen image <wallpaper>` at runtime and wrote generated files straight into
`~/.config/*` (waybar, wlogout, kitty, rofi, the full `dunstrc`, swaylock),
which is incompatible with home-manager's read-only store symlinks. Two
candidate architectures: keep matugen (live re-theme, no rebuild, lots of glue
+ writable-path discipline) or Stylix (declarative, palette derived from a
wallpaper at build time, wallpaper change == rebuild, far less glue). Note: the
old `apply_matugen.sh` inline `generate_*` bash functions and the
`hyprland_colors`/`gtk*` templates were **dead code** — `config.toml`'s
templates were the only thing matugen actually ran.

**Decision:** Use **Stylix** (`modules/nixos/desktop/theming.nix`). Stylix
derives one base16 palette from `stylix.image` and themes the desktop
declaratively; because home-manager runs as a NixOS module, its
home-manager-integration copies `stylix.*` into the maudi home automatically, so
one module themes system + home. Accepting wallpaper-change-equals-rebuild was
explicit. Sub-decisions:

- **Notifications:** dunst → **swaync** (SwayNotificationCenter), themed by
  stylix's swaync target; it registers its own user service.
- **Qt:** `stylix.targets.qt.platform = "qtct"` (the default), which themes Qt
  via a stylix-generated Kvantum theme under qt5ct/qt6ct — no manual Kvantum
  SVG upkeep.
- **Custom-layout apps keep their layouts, palette comes from stylix:** waybar,
  wlogout, rofi and hyprland have hand-tuned configs from Ticket 04. Their
  stylix targets are disabled (waybar/rofi/hyprland; wlogout has no target) and
  their colours are injected from `config.lib.stylix.colors` — waybar/wlogout
  via a prepended `@define-color` block, rofi via a prepended `* { … }` palette
  (passed as a `builtins.toFile` theme path, since a derivation is misread as an
  inline rasi attrset), hyprland keeps its 4-stop gradient borders mapped onto
  base0D/0C/0E. Everything else (GTK, kitty, swaync, swaylock, cursor, fonts,
  icons) is themed directly by stylix.
- **Wallpaper picker** (`pkgs/scripts/theme-wallpaper-select.sh`, SUPER+W):
  rofi-picks an image, repaints it live with swaybg, copies it over
  `modules/nixos/desktop/wallpaper.png` in the local flake checkout
  (`FLAKE_DIR`, default `~/desktop-nix`) and runs `nixos-rebuild switch` so
  stylix re-derives the palette. swaybg still paints `stylix.image`; stylix's
  hyprland target (which would pull in hyprpaper and flatten the gradient) is
  disabled.

**"Ask when starting" resolutions:** Papirus stays as the icon theme
(`stylix.icons`, Papirus-Dark). swaylock references the wallpaper via
`stylix.image` (stylix's swaylock target sets `image=` to a store path — the old
hard-coded `/var/home/maudi/.dotfiles/...` path is gone). The matugen
templates/`apply_matugen.sh` are dropped entirely (not ported).

**Consequences:** Changing the wallpaper is a rebuild, not instant (the picker
gives an instant swaybg preview to soften this). A picked wallpaper persists
only until the next `system.autoUpgrade`, which rebuilds from git `main` and so
restores the committed default `wallpaper.png` unless the change is committed.
The default wallpaper is committed with a deliberately wide luminance range so
the auto-generated dark scheme keeps readable bg/fg contrast. One more flake
input (`stylix`) to track; it follows nixpkgs.

---

## 023 — Shell & CLI environment: fish in home-manager, starship prompt (2026-06-13)

**Context:** Ticket 06 migrates the old MyLinux fish environment (config,
aliases, functions, prompt) and the small tool configs (kitty, fastfetch,
lazygit) off the `setup.sh` symlink + fisher/toolbox flow into declarative
home-manager. The prompt was the crux: the old setup ran fisher to install
`tide`, whose configuration lives in fish **universal variables** written
interactively by `tide configure` — not reproducible on a fresh machine.

**Decision:** A new `modules/home/cli/` module (wired for every host via
`modules/nixos/base/home.nix`, mirroring `modules/nixos/desktop/home.nix`)
owns the shell + CLI environment:

- **Prompt: starship, not tide.** `programs.starship` is declarative by nature
  and stylix has a starship target, so the palette is themed automatically.
  fisher and tide are dropped entirely (no self-update flow, no universal-var
  state).
- **fish via `programs.fish`:** aliases as `shellAliases`, the custom helpers
  (mkcd, extract, killf, backup, duh, gst) as `functions`, greeting/history in
  `interactiveShellInit`. The nvm fisher plugin and `load_nvm` are dropped
  (node → Ticket 08); the per-shell `eval (ssh-agent -c)` is replaced by
  `services.ssh-agent.enable`.
- **Alias audit:** `tb`/`tbr` (toolbox) removed; `update` is now
  `sudo nixos-rebuild switch --flake ~/desktop-nix` (matching the wallpaper
  picker's `FLAKE_DIR`, DECISIONS 022); flatpak aliases dropped pending
  Ticket 10; the `docker`→`podman`, cargo (`cb`/`ct`/`cw`) and `gs`
  (git-spice) aliases are kept but **dormant** — their tools arrive in
  Ticket 08. The no-op self-aliases (`tree`/`fd`/`rg`/`fzf`) are removed.
- **CLI tools in home-manager** (DECISIONS 013): `eza bat fd ripgrep fzf tree
  btop fastfetch delta`, plus `zoxide` via `programs.zoxide` for its fish hook.
- **kitty via `programs.kitty`:** behavioural settings ported; colours and font
  are left to stylix (the old `include colors.conf` is dropped). Terminal
  transparency (old `background_opacity 0.7`) is set via
  `stylix.opacity.terminal = 0.7` because stylix's kitty target owns that key.
- **fastfetch** translated to `programs.fastfetch.settings`; **lazygit** keeps
  its large hand-tuned `config.yml` vendored verbatim (the rofi/waybar
  raw-file idiom). lazygit is installed as a plain `pkgs.lazygit` with the file
  dropped via `xdg.configFile`, *not* through `programs.lazygit`: that module
  unconditionally writes its own `config.yml` (even with empty `settings`),
  which collides with the vendored file at equal priority.

**Consequences:** The prompt looks different from the old tide setup, but is
fully reproducible on a fresh home with no interactive step. git-spice/gh and
the cargo toolchain are referenced by dormant aliases/commands until Ticket 08
installs them. Tests assert fish/starship are enabled (eval-level) and that the
configs render, aliases/functions resolve and the tools are on PATH (the
`test-base-system` VM, since base now wires the cli module).

---

## 024 — Neovim config strategy: keep-as-is via mkOutOfStoreSymlink (2026-06-13)

**Context:** Ticket 07 had to choose between (a) keeping the existing ~40-plugin
lazy.nvim config editable by symlinking it into `~/.config/nvim` and (b) a full
nixvim rewrite where every plugin and option is declared in Nix.

**Decision:** Keep the existing config as-is, linked via
`config.lib.file.mkOutOfStoreSymlink "${home}/desktop-nix/nvim"` in
`modules/home/neovim/default.nix`. Changes to `nvim/lua/plugins/*.lua` take
effect immediately on next nvim launch without a rebuild.

**Consequences:** The config is editable during development — the trade-off is
that it is not purely declarative (lazy-lock.json pins plugins, but plugins
themselves live in `~/.local/share/nvim/`, outside the Nix store). A nixvim
rewrite is deferred until after the migration is stable.

---

## 025 — Mason strategy on NixOS: UI layer only, no auto-install (2026-06-13)

**Context:** The existing config used `mason-tool-installer` to auto-install LSP
servers and formatters, and `mason-nvim-dap` to install DAP adapters. On NixOS,
Mason-downloaded binaries fail due to dynamic-linking (they reference glibc/libstdc++
paths that don't exist outside the Nix store).

**Decision:** Keep `mason.nvim` as a UI layer (`:Mason` still shows status) but
set `ensure_installed = {}` and `automatic_installation = false` everywhere Mason
is configured. All LSP servers (lua_ls, gopls, clangd, html/cssls/jsonls,
yamlls, rust-analyzer), formatters (stylua, prettierd, isort, ruff, gofumpt,
clang-format, jq, sqruff), and DAP adapters (gdb, js-debug-adapter) are
provided via `home.packages` in `modules/home/neovim/default.nix`. LSP servers
are enabled explicitly with `vim.lsp.enable()` rather than via mason-lspconfig's
`automatic_enable`.

**Consequences:** `:Mason` shows all tools as "not installed" (they come from
Nix, Mason doesn't know about them). Core LSP/formatting/debugging functionality
is unaffected — binaries are on PATH and found automatically by
lspconfig/conform/dap.

> **Superseded by DECISION 040 (2026-06-16):** the Mason stack was removed
> entirely; Mason no longer runs. The LSP Manager picker (`<leader>lm`) was also
> rewritten to a hardcoded server list (it no longer calls
> `mason-lspconfig.get_installed_servers()`), so the picker is populated, not
> empty.

---

## 026 — lazy-lock.json: committed for plugin reproducibility (2026-06-13)

**Context:** Ticket 07's open question: commit `lazy-lock.json` in the repo for
pinned plugin versions, or leave it untracked (each machine floats to latest).

**Decision:** Commit `lazy-lock.json`. Plugin versions are pinned to what was
tested in MyLinux. Updating plugins is a deliberate `lazy.nvim` `:Lazy update`
step followed by committing the updated lockfile.

**Consequences:** Fresh installs get the exact plugin set from the lockfile.
The lockfile lives at `nvim/lazy-lock.json`; lazy.nvim writes it to
`~/.config/nvim/lazy-lock.json` which, via the mkOutOfStoreSymlink, resolves
back into the repo checkout at `~/desktop-nix/nvim/lazy-lock.json`. Updates
are committed normally.

---

## 027 — Dev environment: nixpkgs toolchains + devShells/direnv, podman, no toolbox (2026-06-14)

**Context:** Ticket 08 replaces the Silverblue `dev-tools` **toolbox** container
(provisioned imperatively by MyLinux `setup.sh`: `cargo`/`fish` via dnf, then
`cargo install` of `eza`, `matugen`, `cargo-nextest`, `bacon`). `eza` already
moved to Ticket 06 and `matugen` was dropped for Stylix (DECISIONS 022), so the
genuinely-missing dev tools were `cargo-nextest` + `bacon`, plus a container
runtime and the Claude Code config. The language toolchains the ticket lists
(rust/go/node/python/C) were already installed globally — but by the Ticket 07
neovim module, where they were only ever editor build-deps. Several "Open
questions" needed user calls (Rust source, what goes global, node strategy,
distrobox escape hatch).

**Decision:**

- **Rust from nixpkgs**, not fenix/rust-overlay or rustup (rustup is an
  anti-pattern on NixOS; no nightly/pinned-channel need today).
- **Thin global toolchains + per-project devShells.** A new `modules/home/dev/`
  owns the daily-driver toolchains (`cargo rustc rustfmt clippy`, `go`, `nodejs`
  LTS, `python3`+`uv`, `gcc gnumake`) plus the cargo extras (`cargo-nextest`,
  `bacon`) and git tooling (`git-spice`, `gh`). Everything pinned per-project
  goes through `devShells` + direnv/nix-direnv (`programs.direnv`). Template
  flakes (`templates/{rust,go,node,python}`, exposed as flake `templates` and
  `devShells.<lang>`) scaffold a project shell: `nix flake init -t
  ~/desktop-nix#<lang>` then `direnv allow`.
- **Toolchain ownership moves to the dev module.** The Ticket 07 neovim module
  drops the duplicated `cargo/rustc/rustfmt/gcc/gnumake/nodejs` and keeps only
  editor-specific tooling (LSP servers, formatters, DAP). The two always load
  together via `modules/nixos/base/home.nix`, so the home package set is
  unchanged — ownership is just no longer split.
- **Node:** a single global LTS (`nodejs`) replaces nvm/`load_nvm`; per-project
  pinning is a devShell concern.
- **Containers: podman** (`modules/nixos/dev/`, imported by base → all hosts).
  `dockerCompat = true` gives scripts a `docker` shim; the interactive fish
  `docker`→podman alias (Ticket 06) shadows it. `podman-compose` covers the old
  compose workflows. The toolbox/mutable-container pattern is **dropped
  entirely** — no distrobox escape hatch (nothing depended on ad-hoc `dnf`).
- **Dev env on all hosts**, wired in `base` like the cli/neovim modules — the
  ticket's "light profile" split is collapsed since podman is cheap and
  private-laptop is the migration pilot.
- **Claude Code config** ported from MyLinux `claude/` into
  `modules/home/dev/claude/` and linked as **individual files** into `~/.claude`
  (`settings.json`, `statusline.sh`, `CLAUDE.md`, `hooks/{rustfmt-edited,
  clippy-stop}.sh`, `commands/{clippy,nextest}.md`) — never the whole dir, which
  holds live state (`settings.local.json`, `projects/`, …). The rustfmt
  PostToolUse and clippy Stop hooks find their tools on PATH from the dev module
  (no toolbox indirection). `CLAUDE.md` was **updated**, not ported verbatim:
  the old one described Silverblue/rpm-ostree/brew/toolbox, all retired here.

**Consequences:** No mutable dev container; ad-hoc experiments use a throwaway
devShell or `nix shell`. Project toolchains are reproducible and pinned per repo.
Aliases/commands Tickets 06/07 left dormant now resolve (`docker`, `ct`, `cw`,
`ck`, `gs`, npm/nx, lazygit `gh`, `/clippy`, `/nextest`). Tests: eval-level
assertions for podman+direnv, a `test-podman` nixosTest (store-loaded image, no
network), and offline `dev-{node,python,go,rust}-check` devShell smoke compiles.

---

## 028 — Virtualisation: libvirt/KVM on all hosts, wired in base (2026-06-14)

**Context:** Ticket 09 ports maudiblue's virtualisation layer. maudiblue's
`recipe.yml` installs `virt-manager`, `libvirt`, `qemu-kvm`, `virt-viewer` and
enables `libvirtd.service` on **every** machine (it has no per-host split). The
ticket framed NixOS's equivalent as an opt-in per-host module (desktop +
work-laptop, "private-laptop unless wanted") and flagged the host list as a
decision to confirm when starting.

**Decision:**

- **All three hosts get libvirt/KVM** (user call, matching maudiblue's global
  `libvirtd`). Because every host is enabled, the module is imported from
  `modules/nixos/base` (like dev/podman) instead of per host — no enablement
  flag or custom options namespace (the repo has none; wiring is by import).
- **`modules/nixos/virtualisation/`** owns it: `virtualisation.libvirtd.enable`
  with `qemu.package = qemu_kvm`, `programs.virt-manager.enable`, the
  `virt-viewer` package, and `maudi` in the `libvirtd` group (group-rw socket →
  `qemu:///system` needs no password; the Ticket 04 `hyprpolkitagent` covers any
  remaining polkit prompts).
- **Win11-class guests:** beyond maudiblue's parity set, enable `swtpm` (emulated
  TPM 2.0) — an install-time requirement for Windows 11. UEFI/OVMF firmware needs
  no wiring: current nixpkgs removed `virtualisation.libvirtd.qemu.ovmf` and ships
  all of QEMU's OVMF images by default, so virt-manager's firmware dropdown
  already offers the Secure-Boot variant.
- **Default NAT network:** NixOS's libvirtd module does not define libvirt's
  built-in `default` network, so a `libvirt-default-network.service` oneshot
  `net-define`s + `net-autostart`s it (`virbr0`, `192.168.122.0/24`). Guests get
  networking out of the box without a manual `virsh net-start`.
- **VM migration runbook** documented in `modules/nixos/virtualisation/README.md`
  (copy qcow2 + `dumpxml`, fix the firmware/emulator store paths, `virsh
  define`) — feeds the Ticket 14/15 host runbooks.

**Consequences:** Every host carries the qemu/OVMF/swtpm closure (heavier laptop
images, accepted for parity). Tests: eval-level assertions (libvirtd + swtpm
enabled, virt-manager on, maudi in libvirtd group) and a `test-virtualisation`
nixosTest (daemon up, `su maudi` reaches `qemu:///system`, default network
defined+autostart, GUI/console clients installed). Booting a real guest requires
nested KVM and is left to manual on-hardware testing.

---

## 029 — Spotify: nixpkgs unfree (Ticket 10, 2026-06-14)

**Context:** Silverblue installed Spotify as `com.spotify.Client` (Flatpak, system
scope). On NixOS `pkgs.spotify` (unfree) is in nixpkgs and integrates with the
PipeWire stack that Ticket 03 set up.

**Decision:** Use `pkgs.spotify` with an explicit `allowUnfreePredicate` allowlist.

**Consequences:** Fully declarative, no Flatpak runtime needed. The allowlist is the
single authoritative gate for unfree packages — the build fails on any unlisted
unfree package. Steam entries are added when Ticket 11 lands.

---

## 030 — Zen Browser: `0xc000022070/zen-browser-flake`, twilight channel (Ticket 10, 2026-06-14)

**Context:** Options were the `app.zen_browser.zen` Flatpak, the community flake
(`0xc000022070/zen-browser-flake`), or a switch to nixpkgs Firefox (regression). The
Zen team deletes official release artifacts; the community flake's `twilight` channel
mirrors them and is the only reproducible option.

**Decision:** Add `zen-browser` as a flake input (nixpkgs/home-manager follows the
root), use the `twilight` package.

**Consequences:** Release cadence tracked by the community flake maintainer. One extra
flake input. Profile migration from the old machine is a manual step in the Ticket 13
runbook.

---

## 031 — No Flatpak on NixOS (Ticket 10, 2026-06-14)

**Context:** Silverblue used Flatpak as its primary app mechanism (both user and
system Flathub remotes). On NixOS nixpkgs and a community flake cover all four former
Flatpak apps (Spotify → nixpkgs, Zen → zen-browser-flake) or make them unnecessary
(Flatseal, Warehouse).

**Decision:** `services.flatpak` stays disabled (NixOS default). The scope question
from the ticket ("Ask when starting: user vs system scope") is therefore moot.

**Consequences:** Smaller system closure. Sandboxed Flatpak browser is no longer
available; Zen Browser runs unwrapped (acceptable — same as most NixOS installs).

---

## 032 — Flatseal and Warehouse: drop (Ticket 10, 2026-06-14)

**Context:** Both tools exist solely to manage Flatpak apps. With no Flatpak on
NixOS (DECISIONS 031) they serve no purpose.

**Decision:** Drop both. No replacement needed.

**Consequences:** None — their function is subsumed by the declarative Nix config.

---

## 033 — Other GUI apps: thunar, mpv, imv (Ticket 10, 2026-06-14)

**Context:** The Silverblue image provided file management, image viewing, and video
playback outside the Flatpak list (via the base Fedora/Hyprland packages). The NixOS
config must replicate this.

**Decision:** `thunar` (file manager, already added in Ticket 04 desktop packages),
`mpv` (video player, Wayland-native), `imv` (image viewer, Wayland-native). All in
nixpkgs. Added via `modules/nixos/apps.nix` alongside Spotify and Zen Browser.

**Consequences:** Replaces whatever the Silverblue base provided. Config migration for
mpv/imv user preferences (if any) is a manual step in the Ticket 13 runbook.

---

## 034 — Gaming & CachyOS kernel (desktop only) (2026-06-14)

**Context:** Ticket 11 adds gaming support. It is **net-new** — the old
Silverblue image had no gaming or GPU config, so nothing is ported (the only
gaming-adjacent artefact, MyLinux's cosmetic `gamemode.sh` Hyprland toggle, the
user confirmed they never use). The `chaotic-cx/nyx` input and
`chaotic.nixosModules.default` were already wired on the desktop host from
Ticket 01 (`lib/mkHost.nix` `withChaotic = true`).

**Decision:**

- **`modules/nixos/gaming/`** (`kernel.nix` / `steam.nix` / `gpu.nix`), imported
  **only** from `hosts/desktop/default.nix` — never from `modules/nixos/base`.
  The two laptops are battery-first and one runs integrated **Intel** graphics,
  so they get none of this (eval-asserted: scx/steam/32-bit all off on laptops).
- **CachyOS kernel:** `boot.kernelPackages = pkgs.linuxPackages_cachyos` (from
  the chaotic overlay). The chaotic module already adds its binary cache
  (`https://nyx-cache.chaotic.cx/` + trusted key) to the system's `nix.settings`,
  so the kernel is substituted, never built. The same substituter/key is added
  to **CI** (`.github/workflows/ci.yml`, both jobs) so CI substitutes it too.
- **sched-ext:** `services.scx` with `scheduler = "scx_lavd"` (latency-oriented,
  gaming-tuned). gamemode is kept alongside it — cheap, and with no cosmetic
  toggle there is no overlap.
- **Steam:** `programs.steam.enable` + `remotePlay.openFirewall` +
  `gamescopeSession.enable` (Big-Picture session at the greeter) + declarative
  **Proton-GE** via `extraCompatPackages = [ proton-ge-bin ]` (pinned by the
  flake; no imperative protonup-qt). `programs.gamescope.enable` and
  `programs.gamemode.enable` (feralinteractive; `gamemoderun %command%`).
- **Unfree, scoped:** an `nixpkgs.config.allowUnfreePredicate` whitelisting the
  steam package names (`steam`, `steam-unwrapped`, …) instead of a blanket
  `allowUnfree`. Because the module is desktop-only, the laptops keep a fully
  free package set. (`proton-ge-bin`/`steam-run` are already free.)
- **AMD GPU:** mesa/RADV is the NixOS default Vulkan driver (VAAPI included);
  `hardware.graphics.enable32Bit` for 32-bit Steam/Proton titles. **LACT**
  (`services.lact.enable`) for fan/clock/power control (chosen over CoreCtrl).
  Generation-agnostic — no RDNA-specific wiring.
- **MangoHud** overlay configured per-user via
  `home-manager.users.maudi.programs.mangohud` **inside the desktop-only gaming
  module**, so it does not land on the laptops (the shared `modules/home/desktop`
  set is imported by every host).
- **Dropped:** `pkgs/scripts/hypr-gamemode.sh` + its `pkgs/default.nix` entry
  (unused cosmetic toggle).
- **Kernel-update cadence:** chaotic tracks upstream closely and the cachyos
  kernel can move every rebuild. If a kernel regresses, `nixos-rebuild
  switch --rollback` reverts the generation, or pin/hold the `chaotic` flake
  input (don't `nix flake update chaotic`) until a fixed kernel lands.

**Consequences:** The desktop closure carries the cachyos kernel + steam + 32-bit
graphics + LACT (heavier, accepted). The chaotic input now materially affects the
desktop kernel, so `flake.lock` bumps to it should be reviewed. Tests: desktop
eval assertions (cachyos kernel, scx_lavd, steam+32-bit+gamemode, MangoHud),
laptop boundary guards, and a `test-gaming` nixosTest (boots cachyos, scx active
on scx_lavd, steam/gamescope/gamemode/LACT/MangoHud installed, 32-bit driver
tree present). Launching a real game and GPU control need hardware and are left
to manual testing (Ticket 15).

---

## 035 — Secrets management: sops-nix + age (2026-06-15)

**Context:** Ticket 12 establishes a secrets pattern *before* the first real
secret is committed (the work-laptop wireguard key lands in Ticket 14). Secrets
must be encrypted in git and decrypted only on the target host at activation
time, and keyless CI runners must still build every host.

**Decision:**

- **sops-nix over agenix:** YAML files holding multiple keys, multiple
  recipients per file, native age support, and `sops updatekeys` re-keying.
- **Key scheme:** each host decrypts with its SSH host ed25519 key converted to
  age (`sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"]`) plus a
  personal master age key whose private half lives in the **password manager**
  and can decrypt everything. No imperative per-user age key to manage.
- **Wiring:** `inputs.sops-nix.nixosModules.sops` is added in `lib/mkHost.nix`
  (like stylix) and mirrored into the flake's nixosTest nodes, avoiding the
  `_module.args.inputs` recursion. `modules/nixos/base/secrets.nix` only sets
  `sops.age.sshKeyPaths` (and disables GnuPG) — no `defaultSopsFile` and no
  production `sops.secrets` until Ticket 14, which sets `sopsFile` per secret.
- **`.sops.yaml`** holds public keys + creation rules: shared secrets to master
  + all hosts, host-scoped paths to master + that host, and a fixtures rule to a
  known test key only. Per-host recipients are `age1PLACEHOLDER…` placeholders
  filled in at install time (`ssh-to-age` + `sops updatekeys`).
- **Test:** a `test-secrets` nixosTest injects the known test age key, decrypts
  a committed fixture (`secrets/fixtures/test.yaml`) to `/run/secrets`, and
  asserts owner/mode (root and a user secret, both `0400`), non-world-readable,
  and absence of the plaintext from `/nix/store`. The fixture is encrypted only
  to the test key (the VM cannot use a real host key). Keyless CI host builds are
  the negative test that secrets are activation-time, not eval-time.

**Consequences:** Adding a host is a documented `ssh-to-age` + `sops updatekeys`
step (runbook: `docs/runbooks/secrets.md`). The master private key is the single
recovery root and must be backed up. The wireguard key lands in Ticket 14, which
adds the first production `sops.secrets` entry. The jira.nvim / gitlab.nvim API
tokens stay machine-local for now and are revisited in the Ticket 13–14
`~/.config` credential sweep.

---

## 036 — private-laptop pilot: disko + LUKS, Intel iGPU, full-disk wipe (2026-06-15)

**Context:** Ticket 13 brings the first real machine onto NixOS. The pilot
(media + light dev, lowest risk) validates the whole module stack on hardware.
Open questions: partitioning (disko vs manual), LUKS, wipe vs dual-boot,
hostname, and the (undocumented) iGPU.

**Decision:**

- **disko + LUKS, full-disk wipe.** Declarative partitioning via the
  `nix-community/disko` flake input so a reinstall reproduces the exact layout:
  1 GiB ESP (vfat, `/boot`, systemd-boot) + a LUKS2 container filling the rest
  holding the ext4 root. `allowDiscards = true` for SSD TRIM (accepted minor
  metadata leak). Silverblue is **wiped** — the rollback is the installer USB /
  old SSD on a shelf, not dual-boot.
- **Swap = zram, not an encrypted swap partition** — keeps `disk.nix` simple and
  suits a memory-light laptop; no hibernation (accepted).
- **disko is scoped, not global.** The disko module is imported only by
  `hosts/private-laptop/disk.nix`, which is added to the host via `lib/mkHost`'s
  module list in `flake.nix` — **not** `imports`-ed by `default.nix`. The
  nixosTest nodes import `default.nix` alone, so the QEMU VMs keep booting off
  their own scratch disk and never see the LUKS/ESP layout. disko owns
  `fileSystems`; `nixos-generate-config --no-filesystems` produces the rest.
- **Intel iGPU.** `hardware.nix` adds `intel-media-driver` (iHD, Gen8+) +
  `vpl-gpu-rt` and pins `LIBVA_DRIVER_NAME=iHD` for VAAPI/QSV media decode (the
  pilot's main job). Pre-Broadwell hardware falls back to `intel-vaapi-driver`
  / `i965` (documented in the runbook). Plus redistributable firmware and Intel
  microcode.
- **Hostname stays `private-laptop`** — renaming would ripple through the
  `flake.nix` host assertions, kanshi profiles, `.sops.yaml` anchors and test
  nodes for no real benefit.
- **Power management = power-profiles-daemon** (already enabled in the shared
  `modules/nixos/desktop`), not TLP — it is the simpler default and drives the
  existing waybar power-profile module; brightnessctl + udev rules and the
  battery/backlight waybar modules already exist from Ticket 04.
- **Monitor layout:** the old MyLinux `p_laptop.conf` was just
  `monitor=,preferred,auto,1`; the shared kanshi `laptop-internal` fallback
  already covers a single internal panel, so no host-specific profile is added
  (asserted: `kanshiProfileNames == ["laptop-internal"]`).

**Consequences:** The flake gains a `disko` input (review `flake.lock` bumps).
`hardware/hardware-configuration.nix` is generated and committed at install
time (the import is left commented in `default.nix` until then). Executing the
migration on the physical machine and the hardware validation/rollback drill are
manual — they run on the laptop per `docs/runbooks/private-laptop.md`, not in
CI. Pilot lessons feed back into the modules before Tickets 14/15.

---

## 037 — work-laptop: disko + LUKS, Intel iGPU, WireGuard, security hardening (2026-06-15)

**Context:** Ticket 14 brings the work laptop onto NixOS after the private-laptop
pilot (DECISIONS 036). Open questions: disk layout, iGPU, VPN, monitor layouts,
and work compliance requirements (disk encryption, screen lock, SSH exposure,
firewall).

**Decision:**

- **Disk + iGPU = same as pilot (DECISIONS 036).** disko LUKS2 + ext4 + zram,
  Intel iGPU (`intel-media-driver`/iHD, Gen8+; swap to `i965` if pre-Broadwell
  — confirmed during hardware-capture step). Full-disk wipe of Silverblue.
  Disk layout in `hosts/work-laptop/disk.nix`; hardware in
  `hosts/work-laptop/hardware.nix`. Old Silverblue SSD kept un-wiped on a shelf
  until the "Ready for Monday" gate passes.
- **Monitor layouts confirmed:** the two docked kanshi profiles already stubbed
  (`work-laptop-docked-dual`: DP-5 + DP-6, internal off;
  `work-laptop-docked-hdmi`: eDP-1 + HDMI-A-1) match the real desk setups from
  the MyLinux `w_laptop_2Monitors.conf` / `w_laptop_1Monitor.conf` dotfiles.
  Output names and pixel positions to be verified on hardware via `hyprctl
  monitors` at migration start.
- **WireGuard only** (no corporate VPN client). VPN key managed via sops-nix:
  `secrets/work-laptop/wireguard.yaml` (encrypted to master + work_laptop age
  key, created at migration time). NixOS wiring via
  `networking.wg-quick.interfaces.wg0` with `privateKeyFile` pointing at the
  sops-decrypted path; peer details (endpoint, server pubkey, allowed IPs,
  assigned address, DNS) filled in at migration time and committed. Template is
  commented in `hosts/work-laptop/default.nix` with step-by-step instructions.
- **Security hardening on all hosts** (work compliance surfaced the requirement;
  applied universally): new `modules/nixos/base/hardening.nix` sets
  `services.openssh.enable = false` (personal laptops, not servers),
  `users.users.root.hashedPassword = "!"` (root account locked; `nixos-install
  --no-root-passwd` already did this at install, declaration makes it explicit
  and auditable), `networking.firewall.enable = true` (stateful, drop
  unsolicited inbound). Verified via `baseAssertions` in `flake.nix` (SSH
  disabled, root locked, firewall on) and in `test-base-system` nixosTest (SSH
  daemon not running, nft filter table present).
- **swayidle auto-lock** (work compliance: screen lock after a few minutes):
  already implemented at 300 s in `modules/home/desktop/lockscreen.nix` (Ticket
  04) — no change needed.

**Consequences:** `hosts/work-laptop/` gains `hardware.nix`, `disk.nix`, and a
fully wired `default.nix` (hardware imports + commented wireguard stanza). The
`flake.nix` work-laptop host gains `disk.nix` in its modules list (same
scoping trick as private-laptop). `hardening.nix` lands on all three hosts;
the `baseAssertions` and `test-base-system` nixosTest are extended to verify
SSH-off, root-locked, and firewall-enabled. Actual migration (hardware-
configuration.nix, wireguard key, monitor verification) runs on the physical
machine per `docs/runbooks/work-laptop.md`, not in CI.

## 038 — desktop: plain ext4 (no LUKS), AMD GPU, fresh Steam library, single-boot (Ticket 15, 2026-06-15)

**Context:** Ticket 15 brings the gaming + dev desktop onto NixOS — the last
machine off Silverblue and the real-hardware validation for the gaming stack
(Ticket 11 / DECISIONS 034). Open questions on starting: disk layout/encryption,
the existing Steam library, and dual-boot.

**Decision:**

- **Disk: plain ext4, NO LUKS** (diverges from the laptops' DECISIONS 036/037).
  The desktop stays at home — a different physical-security profile than a laptop
  that leaves the building — and skipping LUKS avoids a passphrase prompt at every
  boot on a box that is often powered on headless. Still **disko-managed** for a
  reproducible layout: GPT + 1 GiB ESP (vfat → `/boot`) + ext4 root filling the
  rest. Swap is zram (`hardware.nix`), so no swap partition. Spec in
  `hosts/desktop/disk.nix`, wired via `flake.nix`'s mkHost module list (same
  scoping trick as the laptops, so nixosTest VMs never see it).
- **Steam library: fresh re-download.** No existing partition is preserved or
  mounted. Steam Cloud saves return automatically; **non-cloud saves are backed
  up** in the runbook's pre-migration step. Library lands on the ext4 root.
- **Single-boot.** Wipe Silverblue, install only NixOS — no Windows/dual-boot,
  so no os-prober and no partition to preserve. Anticheat titles handled via
  Proton where they work.
- **AMD hardware** (`hosts/desktop/hardware.nix`): `kvm-amd`, `amd-ucode`
  microcode, `amdgpu` in the initrd for early KMS, `radeonsi` VAAPI. The
  mesa/RADV graphics + 32-bit support and the CachyOS kernel are already owned by
  `modules/nixos/gaming/{gpu,kernel}.nix`, so `hardware.nix` does not redeclare
  them. Exact GPU/CPU model confirmed during the hardware-capture step.
- **Monitor layout confirmed:** the `desktop` kanshi profile
  (`DP-3 = 2560x1440@144 @ 0,0`, `DP-2 = 1920x1080@60 @ 2560,0`) matches the
  MyLinux `hypr/conf/monitors/default.conf` dotfile verbatim. The dotfile has no
  workspace pinning, so none is added (the ticket's mention of pinning does not
  reflect the source). Output names verified via `hyprctl monitors` at migration.

**Consequences:** `hosts/desktop/` gains `hardware.nix` and `disk.nix`;
`default.nix` imports `hardware.nix` (+ commented `hardware-configuration.nix`)
and drops its placeholder inline `fileSystems."/"` (disko owns it). The
`flake.nix` desktop host gains `disk.nix` in its modules list. The existing
`host-assertions-desktop` and `test-gaming` nixosTest already cover the gaming
stack and are unchanged. Actual migration + the MangoHud before/after
performance pass run on the physical machine per `docs/runbooks/desktop.md`,
not in CI.

## 039 — work-laptop compliance hardening: daily updates, audit logging, sudo logging (2026-06-16)

**Context:** The corporate Linux workstation security policy
("Sicherheitsanforderungen für Linux-Arbeitsplätze", §1–§4.8) was checked
against `work-laptop`. The DECISIONS 037 baseline (LUKS2, SSH off, root locked,
firewall) already covered most of it. Three controls were config-closeable gaps:
the update cadence was `weekly` (policy §4.4/§4.5 requires security updates ≤ 72h),
there was no logging of security-relevant events (§4.3/§4.5/§4.6), and sudo had no
explicit logging (§4.3 "Entwickler dürfen sudo … mit Protokollierung"). Applied
to **all hosts** (the policy is a fleet baseline, like DECISIONS 037), not just
work-laptop. Full mapping: `docs/compliance/linux-workstation-policy.md`.

**Decision:**

- **Daily auto-upgrade** (§4.4): `modules/nixos/base/updates.nix` changes
  `dates = "weekly"` → `"daily"` (keeping `randomizedDelaySec = "45min"`,
  `allowReboot = false`). nixpkgs is `nixos-unstable`, so daily pulls keep the
  worst-case security-update window well under the 72h bound.
- **Security-event logging** (§4.3/4.5/4.6): new `modules/nixos/base/audit.nix`
  enables `security.auditd` + `security.audit` with a small laptop-appropriate
  rule set (privilege escalation via sudo/su, writes to `/etc/passwd` `/etc/shadow`
  `/etc/group` `/etc/sudoers`, and time changes), and sets
  `services.journald.storage = "persistent"` so auth/system events survive reboot.
  A full CAPP/STIG profile was rejected as noise for a developer machine.
- **Sudo logging** (§4.3/4.5): `modules/nixos/base/hardening.nix` adds
  `security.sudo.extraConfig` with `Defaults use_pty` and
  `Defaults logfile=/var/log/sudo.log`; `wheelNeedsPassword` stays at its secure
  default (sudo prompts).
- **Out of scope, deliberately:** on-device PAM password complexity
  (`pam_pwquality`) — the company password policy is enforced at the IdP; and
  **WireGuard/VPN activation** (§4.5/4.6 VPN+MFA) — stays templated in
  `hosts/work-laptop/default.nix`, enrolled separately with real keys (the MFA
  half is an IdP/VPN-server concern, off-device).
- **Organisational items** NixOS cannot enforce are documented, not coded:
  the §4.1 Linux asset register (`docs/INVENTORY.md`), and the §4.4 monthly
  update confirmation + §4.8 offboarding process
  (`docs/runbooks/compliance-tasks.md`).

**Consequences:** `modules/nixos/base/default.nix` imports the new `audit.nix`.
`flake.nix` `baseAssertions` gains two checks (auditd enabled; `autoUpgrade.dates
== "daily"`) and `test-base-system` asserts the `auditd` unit is active with the
`priv_esc` rule, `/var/log/sudo.log` configured, and journald persistent — so the
controls cannot silently regress. Verified on real hardware post-migration per
`docs/runbooks/work-laptop.md`.

## 040 — Waydroid: keep on private-laptop + desktop, drop on work-laptop (Ticket 16, 2026-06-16)

**Context:** Ticket 16's first sub-task was a decision, not an implementation:
maudiblue layered the `waydroid` rpm into the image (`recipes/recipe.yml`), but
nothing else in the old setup referenced it — no `waydroid init` automation, no
GAPPS image, no Hyprland window rules in the MyLinux dotfiles. The ticket flagged
it as the most likely "consciously dropped" row in `INVENTORY.md` and said to
confirm usage before porting.

**Decision:** Keep the Android container, but make it **opt-in per host** rather
than global like libvirt (DECISIONS 028). It lands on the two personal machines —
**private-laptop** and **desktop** — and is deliberately **absent from
work-laptop**, whose security baseline (DECISIONS 037/039) has no place for an
Android runtime nobody on that machine needs.

- **Module:** new `modules/nixos/waydroid/default.nix` sets
  `virtualisation.waydroid.enable = true` (parity with the layered rpm: pulls in
  the waydroid CLI, lxc tooling and binder bits, registers
  `waydroid-container.service`). Imported only from `hosts/private-laptop` and
  `hosts/desktop`, **not** from `modules/nixos/base` — the same desktop-only
  pattern the gaming stack uses (DECISIONS 034).
- **Hyprland integration:** the module contributes three `windowrule`s to maudi's
  home Hyprland config (float the `waydroid.*` app toplevels and the `Waydroid`
  full-UI launcher in multi-window mode; idle-inhibit while an Android window is
  focused). They merge with the shared `windowrule` list in
  `modules/home/desktop/hyprland.nix` and only land on the waydroid hosts.
- **Stays imperative** (documented in the module header): `sudo waydroid init`
  (one-time system/vendor image download; `-s GAPPS` for the Play image),
  `waydroid session start` / `show-full-ui`, and the Android data under
  `~/.local/share/waydroid` + `/var/lib/waydroid` (user state, kept out of the
  store).

**Open question deferred:** the GAPPS / Google-Play image (device registration +
licensing hassle) is *not* wired in. `waydroid init` defaults to the vanilla
LineageOS image; GAPPS stays a manual `-s GAPPS` choice if a Play-only app ever
forces it.

**Consequences:** `flake.nix` `host-assertions-private-laptop` and
`host-assertions-desktop` assert `virtualisation.waydroid.enable`, and
`host-assertions-work-laptop` asserts it is **off** — so the per-host split
cannot silently regress. A new `test-waydroid` nixosTest (on the shared
private-laptop test node) checks the CLI and `waydroid-container.service` unit are
installed and the window rules rendered; a full Android boot needs binder + KVM +
the imperative image download, so it is left to on-hardware manual testing.

## 041 — Audit rules: syscall-based priv-esc, drop nonexistent-path watches (fix DECISIONS 039, 2026-06-16)

**Context:** The `test-base-system` nixosTest had been failing in CI ever since
DECISIONS 039 added auditd — `main` itself was red. The assertion
`machine.wait_until_succeeds("auditctl -l | grep -q priv_esc")` timed out after
900s because **no audit rules were ever loaded**. NixOS applies
`security.audit.rules` from `audit-rules-nixos.service`, a oneshot that runs at
`sysinit.target` (`DefaultDependencies = false`, `before sysinit.target`) and
calls `auditctl -R rules`. `auditctl -R` aborts the *entire* load on the first
erroring line, and `auditctl` resolves `-w` watch paths to an inode at load time.
Three watched paths do not exist when the rules load:

- `/run/wrappers/bin/sudo` — the setuid wrappers tmpfs (`/run/wrappers`) is
  populated by `suid-sgid-wrappers.service`, much later than sysinit. This was
  line 5 (the first rule), so it aborted every load: `Error sending add rule
  data request (No such file or directory) … There was an error in line 5 … No
  rules`.
- `/etc/gshadow` — NixOS's users-groups activation writes `/etc/{passwd,shadow,
  group}` but never `/etc/gshadow`.
- `/etc/sudoers.d` — the sudo module manages only `/etc/sudoers`, not a
  `sudoers.d` directory.

This failed identically on real hardware; it was only ever "verified" as
`auditd.service` being active, not as rules being live, and the PR merged red.

**Decision:** Keep the §4.3/4.5/4.6 intent (log privilege escalation, identity/
authorisation-DB changes, and time changes) but make the rule set load-order- and
path-independent:

- **Privilege escalation** is now syscall-based instead of a wrapper-path watch:
  `-a always,exit -F arch=b64 -S execve -F euid=0 -F auid>=1000 -F auid!=4294967295 -k priv_esc`
  (plus the `b32` ABI). This flags any logged-in user (`auid >= 1000`) executing
  a program that runs as root (`euid 0`) — i.e. sudo/su and kin — and resolves
  no path at load time. It is also broader than the old two-wrapper watch.
- **Identity/authorisation watches** keep only the files NixOS actually creates
  (`/etc/passwd`, `/etc/shadow`, `/etc/group`, `/etc/sudoers`); the `/etc/gshadow`
  and `/etc/sudoers.d` watches are dropped (nothing exists there to watch).
- **time_change** is unchanged (already syscall-based).

**Consequences:** `modules/nixos/base/audit.nix` carries the new rule set.
`test-base-system` now asserts `audit-rules-nixos.service` is active and the
`priv_esc` rule is live with plain `succeed` (not a 900s `wait_until_succeeds`),
so a future rule-load regression fails in seconds instead of timing out. This
turns CI green for the first time since DECISIONS 039. Amends — does not revoke —
DECISIONS 039: the controls and their keys (`priv_esc`, `identity`, `privileges`,
`time_change`) are preserved.

## 042 — Per-host update channels: pilot/desktop on `main`, work-laptop on a CI-gated `release` branch (audit ST-1, 2026-06-16)

**Context:** The pre-go-live audit (`docs/audit/pre-golive-review.md`, ST-1)
flagged that every host — including the HA / policy-bound work-laptop — pulled
`main` on the same daily timer (DECISIONS 011/039). CI proves a host *builds*,
not that it *runs* on real hardware, and with one shared channel the work laptop
could break the same day as the private-laptop pilot. Options considered:
manual-only on the work laptop (one-line `enable = false`); stagger it a day
behind with a time delay; or point it at a separate promoted ref.

**Decision:** Split the update channel per host. private-laptop (pilot) and
desktop keep tracking `main`. The work-laptop tracks a **`release` branch** that
a CI workflow (`.github/workflows/promote-release.yml`) fast-forwards to a `main`
commit **once that commit's `build-hosts` CI is green** — build-gated, no time
delay (the user's call: a runtime soak window was considered and declined). A
fixed git *tag* cannot serve here because `system.autoUpgrade.flake` needs a
*moving* pointer; a branch is "the tag the pipeline advances". Wiring:
`modules/nixos/base/updates.nix` sets `flake = lib.mkDefault "github:…/desktop-nix"`
(= `main`) and `hosts/work-laptop/default.nix` overrides it to `…/desktop-nix/release`.
All hosts stay on the same `daily` cadence (DECISIONS 039 unchanged). The
threading uses `mkDefault` + a per-host override rather than a `mkHost`
specialArg because the nixosTest nodes import the host `default.nix` files
directly (not via `mkHost`), so a required specialArg would break eval.

**Consequences:** `flake.nix` `baseAssertions` gains a hostname-aware check
(work-laptop's `autoUpgrade.flake` ends in `/release`; the others do not), so the
routing cannot silently regress. The `release` branch must exist before the work
laptop's `autoUpgrade` works — it is created on the first `promote-release` run
(pushing to a missing ref creates it) or seeded manually
(`git push origin main:release`); see `docs/runbooks/updates.md`. Supersedes the
single-channel half of DECISIONS 011. ST-4 (desktop's bleeding-edge kernel on the
fast channel) is mitigated by DECISIONS 045 (bounded rollback) rather than by
slowing the desktop down.

## 043 — Scheduled flake.lock auto-update, auto-merge on green (audit ST-2, 2026-06-16)

**Context:** Audit ST-2: `system.autoUpgrade` runs `nixos-rebuild --flake …`,
which rebuilds from the **committed** `flake.lock`; it does **not** run
`nix flake update`. So new nixpkgs (and security fixes) only reach hosts when a
human bumps the lock and merges, and CI ran only `on: push`/`pull_request` with
no `schedule:`. The §4.4/§4.5 "security updates ≤ 72h" claim was therefore
process-dependent, not mechanical.

**Decision:** Add `.github/workflows/update-lock.yml`: a daily (`schedule`)
job that runs `nix flake update`, opens a PR via `peter-evans/create-pull-request`,
and enables native auto-merge so the existing CI (`flake check` + `build-hosts`)
gates it and it lands on green. The user chose auto-merge-on-green over a manual
merge gate (fast security updates; "daily on Silverblue never broke"). Promotion
to the work-laptop `release` branch then follows via DECISIONS 042. The bot uses
a fine-grained PAT (`LOCKBUMP_TOKEN`) rather than the default `GITHUB_TOKEN`,
because PRs/pushes made with `GITHUB_TOKEN` do not trigger `on: pull_request` /
`on: push` workflows — without a PAT the bot PR's CI would never start and
auto-merge would never fire.

**Consequences:** New one-time repo setup, documented in
`docs/runbooks/updates.md`: create the `LOCKBUMP_TOKEN` secret (`contents` +
`pull-requests` write), enable "Allow auto-merge", and protect `main` requiring
the `nix flake check` + `Build *` checks so auto-merge waits for them. With this
in place the ≤72h window is mechanical: nixpkgs fix → daily lock-bump PR →
auto-merge on green → `main` (pilot/desktop) within a day, `release` (work-laptop)
as soon as `main` is green. The compliance mapping §4.4/§4.5 is updated to cite
this job.

## 044 — Bootstrap password: hashed + forced first-login change (audit S-1, 2026-06-16)

**Context:** Audit S-1: `modules/nixos/base/users.nix` shipped
`initialPassword = "changeme"` — weak, identical on every host, **and** landing
as plaintext in the world-readable Nix store. A stale comment claimed Ticket 12
(secrets) had replaced it; it had not. The proper sops path
(`hashedPasswordFile`) needs real host age keys, which are still unenrolled
(audit S-4), so it cannot be validated in CI yet.

**Decision:** Ship the bootstrap credential as a **hash** via
`initialHashedPassword` (yescrypt, generated with `mkpasswd -m yescrypt`) so no
plaintext reaches the store, set `users.mutableUsers = true` explicitly, and
**force a one-time password change at first login** with a
`system.activationScripts` step that runs `chage -d 0 maudi` guarded by a stamp
file (`/var/lib/nixos/.maudi-initial-pw-expired`) so a later rebuild never
re-expires a password the user has since set. This matches the user's preference
("plaintext is fine *only* if a first-login change is forced; otherwise hash it")
— we do both. Migrating to a sops `hashedPasswordFile` remains the documented
next step once host keys are enrolled.

**Consequences:** `modules/nixos/base/users.nix` carries the hash, the explicit
`mutableUsers`, and the activation step; the stale Ticket-12 comment is removed.
No machine ships a store-readable plaintext password, and every machine forces
the user off the shared bootstrap secret at first login. The hash is a throwaway
bootstrap value — replace it (or wire sops) per `docs/runbooks/updates.md`.

## 045 — Bounded rollback: systemd-boot configurationLimit (audit ST-3/ST-4, 2026-06-16)

**Context:** Audit ST-3: `boot.nix` set no
`boot.loader.systemd-boot.configurationLimit`, so the boot menu was unbounded,
and GC (`nix.nix`, `--delete-older-than 30d`) bounded the rollback set by *time*,
not by a count of known-good generations — exactly the safety net an HA machine
(and the desktop's bleeding-edge CachyOS kernel, ST-4) leans on after a bad
unattended upgrade.

**Decision:** Set `boot.loader.systemd-boot.configurationLimit = 20` fleet-wide
in `modules/nixos/base/boot.nix`. Combined with `allowReboot = false` (a bad
kernel only bites on the next *manual* reboot, with the prior generation still in
the menu), this is judged sufficient for ST-4 — pinning the desktop kernel was
rejected as fighting the fast-security-update goal (DECISIONS 042/043).

**Consequences:** Always at least 20 generations available to roll back to from
the boot menu, independent of the 30-day GC window. The desktop's bleeding-edge
kernel keeps a known-good fallback; the threat model for an unattended bad kernel
bump is "reboot, pick the previous generation".

## 046 — Go-live security posture: conscious-decision items kept deliberately (audit S-2/S-3/S-6/S-7/ST-6/Q-5, 2026-06-16)

**Context:** Several audit findings are flagged as conscious-decision / ADR
items, not defects — each a "keep or trim" call for go-live. The user reviewed
them and chose to keep the current behaviour, with concrete reasons.

**Decision (keep as-is, recorded here so they are deliberate, not drift):**

- **S-6 `hardware.bluetooth.powerOnBoot = true`** (`audio.nix`): **kept** — the
  user's keyboard is Bluetooth, so powering the radio on at boot is required to
  log in. Turning it off would lock the user out of the machine.
- **S-2 `trusted-users = [ "root" "maudi" ]`** (`nix.nix`) and **S-3/S-7 libvirt
  + `qemu.runAsRoot`** (`virtualisation/libvirt.nix`, DECISIONS 028): **kept** —
  the user's Docker/VM workflows depend on them; trimming risks breaking daily
  development. `maudi` being daemon-root-equivalent and the always-on `virbr0`
  NAT are accepted on this single-user developer machine.
- **Q-5 `alsa.support32Bit = true`** fleet-wide (`audio.nix`): **kept** — harmless
  on the laptops; not worth a per-host split.
- **ST-6 Zen Browser `twilight`** (`apps.nix`, DECISIONS 030): **kept** — the
  user is comfortable with fast-moving software (the whole fleet tracks
  `nixos-unstable` daily), and `twilight` is the only reproducible Zen channel.

**Consequences:** These are now documented go-live decisions rather than open
audit findings. The residual exposure (daemon-root-equivalent `maudi`, BT attack
surface, root QEMU, a nightly browser) is accepted for a single-user developer
fleet and noted in the audit resolution log
(`docs/audit/pre-golive-review.md`).

## 041 — Neovim: remove the Mason stack entirely (NV-Q-6, 2026-06-16)

**Context:** DECISION 025 kept `mason.nvim`, `mason-lspconfig.nvim`,
`mason-tool-installer.nvim` and `mason-nvim-dap.nvim` as a "UI layer only" with
`ensure_installed = {}` everywhere. All servers/formatters/DAP adapters already
come from Nix (`home.packages`), servers are enabled with `vim.lsp.enable()`, and
the `<leader>lm` picker was rewritten to a hardcoded list — so the four Mason
plugins installed nothing and `:Mason` only ever showed everything as
"not installed". The nvim audit (`docs/audit/nvim-review.md` NV-Q-6) flagged this
as dead indirection.

**Decision:** Remove all four Mason plugins. `plugins/nvim-lspconfig.lua` drops the
mason dependencies and the `mason-tool-installer`/`mason-lspconfig` `setup()`
calls; `plugins/dap-debugging.lua` and `plugins/nvim-dap-ui.lua` drop the
`mason-nvim-dap` spec, dependency and handler; the four entries are removed from
`nvim/lazy-lock.json`; the `:Mason` row is removed from `nvim/cheatsheet.html`.

**Consequences:** No behaviour change — LSP attaches, formatters run and DAP
adapters resolve exactly as before, all from Nix-provided binaries on PATH. One
fewer Go/Rust-free plugin set to clone on a fresh install. `:Mason` is gone;
`:checkhealth` no longer reports Mason. Finishes what DECISION 025 started (025's
consequence note is updated to point here).

## 042 — Neovim: lean-down + security/quality fixes from the nvim audit (2026-06-16)

**Context:** `docs/audit/nvim-review.md` raised stability/security/quality items
beyond the Mason removal (041). The user chose, per finding, to lean the config
down and apply the fixes.

**Decision:**

- **Plugins cut** (NV-ST-1 / NV-Q-3 / NV-Q-4): `hardtime.nvim` (training,
  unpinned — closed the one `lazy-lock.json` reproducibility hole), `fff.nvim`
  (Rust-built extra picker — snacks covers it), `fzf.vim` + the bare `junegunn/fzf`
  spec (legacy finder, fzf built twice — fzf-lua keeps its own `fzf` dep), `typr`
  (typing game), and the personal/work integrations `jira.nvim`, `gitlab.nvim`,
  `obsidian.nvim`, `kulala.nvim`. `oil.nvim` was **kept** but lazy-loaded.
  `fyler.lua.disabled` (dead file) deleted.
- **Security** (NV-S-1): the project-root `rust-analyzer.json` deep-merge in
  `rustaceanvim.lua` now reads through `vim.secure.read` (trust prompt) instead of
  unconditionally — a hostile cloned repo can no longer inject
  `overrideCommand`/build-script/proc-macro settings on open. `binary_picker` in
  `dap-debugging.lua` now `shellescape`s `cwd` (NV-S-4).
- **Quality** (NV-Q-1): `conform.nvim` formatter list fixed — removed the
  non-existent `"inject"` formatter and tools not provided by Nix
  (`sqlfluff`/`pg_format`/`xmlformatter`/`prettier`); SQL aligned on `sqruff`.
- **Lazy-loading** (NV-ST-3): `oil` (`cmd`/`keys`) and `fzf-lua` (`keys`) no longer
  `lazy = false`.
- **Housekeeping**: kitty-padding autocmds guarded on `$KITTY_WINDOW_ID`
  (NV-ST-5); which-key groups reconciled with the real keymaps, `<leader>d`
  relabelled Debugger (NV-Q-5); `stylua`/`luacheck` clean-up (NV-Q-8); Ruby/Node/
  Perl neovim providers disabled, only python3 kept (NV-Q-9); `init.lua` modeline
  `ts=2`→`ts=4` and `vim.wo`→`vim.o` (NV-Q-10); dead commented blocks removed
  (NV-Q-2); cheatsheet updated.

**Consequences:** A leaner, fully-pinned plugin set; format-on-save works on the
primary languages again; opening external Rust repos no longer auto-executes
project-supplied settings. `docs/audit/nvim-review.md` carries a resolution note.
