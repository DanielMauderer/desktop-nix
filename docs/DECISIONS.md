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
  raw-file idiom) under `programs.lazygit.enable`.

**Consequences:** The prompt looks different from the old tide setup, but is
fully reproducible on a fresh home with no interactive step. git-spice/gh and
the cargo toolchain are referenced by dormant aliases/commands until Ticket 08
installs them. Tests assert fish/starship are enabled (eval-level) and that the
configs render, aliases/functions resolve and the tools are on PATH (the
`test-base-system` VM, since base now wires the cli module).
