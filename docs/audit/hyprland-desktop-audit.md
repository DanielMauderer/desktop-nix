# Hyprland / Desktop Dotfiles Audit — `desktop-nix`

**Date:** 2026-06-16
**Scope:** The Hyprland/Wayland desktop layer + terminal cosmetics — stability ·
security · quality · cleanup — ahead of going live.
**Reviewer:** automated config audit (read-only; no config files were changed).
**Branch reviewed:** `claude/hopeful-cray-p6bua1` @ `8e5edc5`.

> This is a **report only** (confirmed output mode). Nothing in the
> configuration was modified. Each finding has a severity, exact file
> references, and a recommendation for you to apply. This audit deliberately
> covers the layer the prior `pre-golive-review.md` **excluded by request**
> (Hyprland, waybar/rofi/wlogout/swaync, CLI cosmetics), so the two together
> now cover the whole repo minus nvim and the already-reviewed Nix infra.

---

## 1. Executive summary

The desktop layer is in good shape and clearly past the "raw ml4w copy" stage:
the old MyLinux/ml4w config trees have been translated into native
home-manager settings (`wayland.windowManager.hyprland.settings`,
`programs.waybar`, `programs.rofi`, `programs.wlogout`, `services.swaync`,
`services.kanshi`), the runtime-mutation hacks (monitor-hotplug, focus-mode
file rewrites) were redesigned around kanshi + `hyprctl keyword`, and the
surviving shell scripts are packaged with `writeShellApplication` (shellcheck
at build, explicit `runtimeInputs`). The `ml4w` **directory/namespace rename is
already done** (DECISIONS 020) — what remains is text residue and a handful of
dead rules.

There are **no go-live blockers** in this layer. The findings cluster as:

- **Cleanup (the bulk):** a few dead window/layer rules and orphaned packages
  (color picker, emoji picker, browser tiling rules), stale `dunst` comments
  after the swaync migration, dead CSS selectors, and the last `ml4w` text
  mentions. These are exactly the "dead config parts no longer used" you flagged.
- **Stability:** a **broken Hibernate action** shipped on a swapless fleet, and
  always-on heavy compositor effects (notably a looping `borderangle` animation)
  worth trimming on the **work-laptop** (HA/battery).
- **Desktop gaming:** there is currently **no Hyprland-level gaming tuning**
  (tearing/VRR/`immediate` rules). Audited & recommended only, per your call.
- **Quality:** a few hardcoded (non-stylix) colours, a hardcoded cursor that
  may fight stylix, a fragile `kill`-by-PID keybind, and some keymap gaps.

### Go / no-go posture (this layer)

| Host | Posture |
|---|---|
| **private-laptop** (pilot) | **GO.** Single internal panel; lowest stakes. Apply CL/QL cleanup at leisure. |
| **desktop** (gaming) | **GO.** Stable as-is. Gaming gains (GM‑1/GM‑2) are upside, not blockers; idle-suspend (ST‑3) worth a look. |
| **work-laptop** (HA) | **GO.** Consider ST‑1 (broken hibernate) and ST‑2 (effects/battery) for an HA machine, plus verifying the dock kanshi/workspace story on hardware. |

---

## 2. Methodology & scope

**In scope (read in full):**
- `modules/home/desktop/**` — `hyprland.nix`, `waybar.nix` + `waybar-style.css`,
  `rofi.nix` + `rofi-theme.rasi`, `wlogout.nix` + `wlogout-style.css`,
  `swaync.nix`, `kanshi.nix`, `lockscreen.nix`, `packages.nix`, `default.nix`.
- `pkgs/scripts/*` (the hypr/waybar + wallpaper wrappers) and `pkgs/default.nix`.
- Terminal cosmetics (in scope by request): `modules/home/cli/**` —
  `kitty.nix`, `fastfetch.nix`, `fish.nix`, `lazygit.nix`, `default.nix`.
- Per-host Hyprland/kanshi/idle overrides in `hosts/*/default.nix`.

**Out of scope:** the Nix infra/flake/CI/secrets layer (covered by
`pre-golive-review.md`), nvim (`nvim/**`, `modules/home/neovim`), and the
ticket backlog.

**How it was checked:** direct read of every in-scope file; cross-referencing
binds/rules/modules against what is actually installed (`packages.nix`,
`home.packages`) and reachable; and tracing each script's `runtimeInputs`. The
config was **not** built or launched (report-only); findings about
auto-detected behaviour (waybar temperature, kanshi output names) are flagged
as **verify-on-hardware**.

**`kb_layout = "eu"`** (EurKEY) is confirmed intentional and is **not** a
finding.

---

## 3. Findings

Severity: **P1** = fix before relying on the machine · **P2** = cleanup /
nice-to-have / conscious-decision item. (No P0 blockers found.) Categories:
**CL** cleanup/dead-config · **ST** stability · **SE** security · **QL**
quality · **GM** gaming · **HX** host/consistency.

| ID | Sev | Cat | Host(s) | Finding | File |
|---|---|---|---|---|---|
| **ST‑1** | P1 | Stability | all | Hibernate is offered but cannot work: the fleet is zram-only / no swap device, so `systemctl hibernate` fails. Exposed via the wlogout **Hibernate** button and the `hibernate` shell alias | `modules/home/desktop/wlogout.nix:47`, `modules/home/cli/fish.nix:46` |
| **CL‑1** | P2 | Cleanup | all | Stale `dunst` references after the swaync migration (DECISIONS 022) — dunst is no longer used anywhere | `modules/home/desktop/hyprland.nix:212`, `modules/home/desktop/packages.nix:18` |
| **CL‑2** | P2 | Cleanup | all | Last `ml4w` text residue (the dir/namespace rename is done — DECISIONS 020 — but the name lingers in a code comment + docs) | `modules/home/desktop/hyprland.nix:212`, `docs/tickets/04-*.md`, `docs/INVENTORY.md:102`, `docs/DECISIONS.md:300` |
| **CL‑3** | P2 | Cleanup | all | `hyprpicker` is installed and has a `layerrule`, but **no keybind launches it** → orphaned tool + rule | `modules/home/desktop/packages.nix:13`, `hyprland.nix:268` |
| **CL‑4** | P2 | Cleanup | all | Emoji-picker window rules for `it.mijorus.smile`, but the app is **not installed** and **no bind launches it** → dead rules | `modules/home/desktop/hyprland.nix:251-253` |
| **CL‑5** | P2 | Cleanup | all | Browser-tiling rules for Microsoft-edge / Brave / Chromium, but the actual browser is **Zen** (`SUPER+B`, DECISIONS 030) and none of those browsers are installed → likely dead rules | `modules/home/desktop/hyprland.nix:215-217` |
| **CL‑6** | P2 | Cleanup | all | Dead/malformed CSS selectors carried over verbatim: `#custom-notification`, `#wireplumber.muted`, `#group-6/7/8` (no such modules on the bar), and `#window#waybar` (malformed — no space) | `modules/home/desktop/waybar-style.css:27,86,90-100,113` |
| **ST‑2** | P2 | Stability | work-laptop | Always-on heavy compositor effects fleet-wide (blur size 8/passes 3, shadows, dim) **plus a looping `borderangle` animation** that keeps the GPU rendering continuously → battery/thermal cost on the HA laptop | `modules/home/desktop/hyprland.nix:130-155,179` |
| **ST‑3** | P2 | Stability | desktop | Idle auto-suspend at 10 min comes from the shared default; only work-laptop overrides it (→30 min). A gaming desktop can suspend mid-download/install/cutscene (the `idleinhibit` rule only covers *fullscreen*) | `modules/home/desktop/lockscreen.nix:31`, `hosts/desktop/default.nix` (no override) |
| **ST‑4** | P2 | Stability | all | `pavucontrol`/volume keys drive `pactl` and the full `pulseaudio` client is installed on a PipeWire system — redundant; volume control should go through PipeWire (`wpctl`/`pamixer`) or rely on `pipewire-pulse`'s `pactl` | `modules/home/desktop/packages.nix:17`, `hyprland.nix:330-333` |
| **SE‑1** | P2 | Security | all | Fragile/unsafe kill bind: `hyprctl activewindow \| grep pid \| tr -d 'pid:' \| xargs kill`. `tr -d 'pid:'` strips those letters from the *whole* line and depends on output format — can target the wrong PID | `modules/home/desktop/hyprland.nix:290` |
| **SE‑2** | P2 | Security | all | `theme-wallpaper-select` runs `sudo nixos-rebuild switch` from a keybind-launched GUI script. Confirm an askpass/agent is wired for a Wayland session, or it can hang/fail silently with no TTY | `pkgs/scripts/theme-wallpaper-select.sh:62` |
| **SE‑3** | P2 | Security | all | kitty `allow_remote_control = yes` + listen socket: any process in the user session can drive the terminal (run commands). The per-user `$XDG_RUNTIME_DIR` socket (0700) bounds it; flagging for the work-laptop threat model | `modules/home/cli/kitty.nix:38-39` |
| **QL‑1** | P2 | Quality | all | Hardcoded non-stylix colours break the themed palette: waybar VPN connected/disconnected `#a6e3a1`/`#f38ba8` (catppuccin) and wlogout button `#e2e2e9` | `modules/home/desktop/waybar-style.css:140,144`, `wlogout-style.css:15` |
| **QL‑2** | P2 | Quality | all | Cursor is hardcoded (`hyprctl setcursor Bibata-Modern-Ice 24` + `XCURSOR_SIZE,24`) although the comment says cursor is owned by `stylix.cursor`; if `stylix.cursor.{name,size}` differ this fights it | `modules/home/desktop/hyprland.nix:81,88` |
| **QL‑3** | P2 | Quality | all | Keymap gaps: no bind for the colour picker (`hyprpicker -a`), clipboard history (no `cliphist` at all), swaync toggle (`swaync-client -t`), or a full-output screenshot; the old "show keybinds" helper was dropped with no replacement | `modules/home/desktop/hyprland.nix:282-344` |
| **QL‑4** | P2 | Quality | all (per host) | waybar `temperature` has no `hwmon-path`/`thermal-zone`, so it relies on auto-detection — can read the wrong/zero zone per machine (ticket 04 already noted this) | `modules/home/desktop/waybar.nix:117` |
| **GM‑1** | P2 | Gaming | desktop | No Hyprland-level gaming tuning: `allow_tearing = false` globally and no per-game `immediate` window rule → tearing/latency path off even on the gaming box | `modules/home/desktop/hyprland.nix:118` |
| **GM‑2** | P2 | Gaming | desktop | No VRR (`misc.vrr`) and no per-host desktop override to relax effects/idle for fullscreen games (beyond the generic `idleinhibit fullscreen`) | `modules/home/desktop/hyprland.nix:205-209`, `hosts/desktop/default.nix` |
| **HX‑1** | P2 | Host/consistency | desktop, work-laptop | No **workspace→monitor** assignments anywhere. kanshi sets output *geometry* only; ticket 04 promised per-host workspace pinning "in tickets 13–15" but none exists. On dual-head desktop / docked laptop, workspaces aren't pinned to outputs | `hosts/desktop/default.nix:34`, `hosts/work-laptop/default.nix:40` |
| **QL‑5** | P2 | Quality | all | kitty `scrollback_lines = 2000` is low for a primary terminal; `update` alias omits `#host` (works via hostname auto-detect, but implicit) | `modules/home/cli/kitty.nix:23`, `fish.nix:42` |

---

## 4. Detail by priority

### 4.1 Stability (work-laptop HA first)

**ST‑1 — Hibernate is a broken action (P1, UX/stability).** The fleet runs
zram only, with no swap device or swapfile (confirmed in the prior audit's
ST‑5). `systemctl hibernate` therefore has nowhere to write the image and
fails. Yet hibernate is presented to the user in two places: the **wlogout
power menu** (`wlogout.nix:47-52`, keybind `h`) and the **`hibernate` shell
alias** (`fish.nix:46`). On an HA machine especially, an action that looks
available but silently fails is worse than no action.
*Recommendation:* remove the wlogout Hibernate button and the `hibernate`
alias; **or**, if hibernate is wanted, add encrypted swap (a resume device)
and wire `boot.resumeDevice`/`resume` — but that's a Nix-infra change outside
this layer, so default to removing the dead actions.

**ST‑2 — Always-on heavy effects + a looping animation (work-laptop).** The
decoration block enables 3-pass blur (size 8), shadows (range 25), and dim on
every window fleet-wide; the animations list includes
`"borderangle, 1, 100, linear, loop"` (`hyprland.nix:179`) — a *continuously
looping* gradient-border animation that keeps the compositor rendering even
when nothing else changes. On the desktop this is free eye-candy; on the
work-laptop it is a steady battery/thermal draw and an avoidable source of
"why is the GPU always at X%". *Recommendation:* keep the rich profile on the
desktop, but on the work-laptop trim to a lighter set (drop the looping
`borderangle`, reduce blur passes, optionally disable shadows) via a per-host
`wayland.windowManager.hyprland.settings` override — the same per-host override
pattern already used for swayidle/kanshi.

**ST‑3 — Desktop idle-suspend.** `lockscreen.nix` suspends at 10 min for every
host that doesn't override it; only work-laptop does (→30 min). The gaming
desktop inherits 10 min, and `idleinhibit fullscreen` only inhibits idle for
*fullscreen* windows — a long shader-compile, a game patch download in a
windowed launcher, or a paused windowed game can still trip suspend.
*Recommendation:* add a desktop override (longer timeout, or drop the suspend
timeout and keep only the lock) the same way work-laptop overrides it.

**ST‑4 — PipeWire vs the pulseaudio client.** Volume keys call `pactl`
(`hyprland.nix:330-333`) and the full `pulseaudio` package is in
`home.packages` (`packages.nix:17`). On a PipeWire system the `pactl` shim is
provided by `pipewire-pulse`; installing the real `pulseaudio` client is
redundant and risks confusion about which daemon is authoritative.
*Recommendation:* drop the `pulseaudio` package and either rely on the
PipeWire-provided `pactl` or switch the binds to `wpctl set-volume`/`pamixer`.

### 4.2 Desktop gaming (audited & recommended only)

The Nix-side gaming stack (CachyOS kernel, scx_lavd, Steam/Proton-GE,
gamescope, gamemode, RADV + 32-bit, LACT, MangoHud) is correctly desktop-scoped
and was validated in the prior audit. What's **absent is the compositor-side
tuning** that lets that stack actually reduce latency under Hyprland:

- **GM‑1 — tearing path.** `general.allow_tearing = false`
  (`hyprland.nix:118`) disables immediate-mode presentation globally, and there
  is no per-game `windowrule = "immediate, class:^(steam_app_.*)$"` (or per
  title). For competitive/uncapped titles, enabling tearing on the desktop +
  an `immediate` rule for games is the standard win. *Recommendation
  (desktop-only override):* set `allow_tearing = true` and add an `immediate`
  window rule scoped to game classes; leave laptops untouched.
- **GM‑2 — VRR & effects under games.** No `misc.vrr` is set (0 = off). On a
  144 Hz adaptive-sync desktop, `vrr = 1` (or `2`) is worth enabling. Combined
  with ST‑2, consider a desktop "game mode" that the existing
  `hypr-focus-mode`/gamemode hook could extend to also drop blur/shadows for
  the active game. *Recommendation:* enable VRR on the desktop; treat a
  blur/shadow drop for fullscreen games as an optional enhancement.

Both are **upside, not blockers** — and both want on-hardware verification
(VRR/tearing interact with the specific monitor + amdgpu).

### 4.3 Cleanup / dead config / ml4w residue

This is the bulk of the "before going live" tidy you asked for. None affect
behaviour; all are safe to delete.

- **CL‑1 (dunst):** swaync replaced dunst (DECISIONS 022), but
  `hyprland.nix:212` still says "dunst + kanshi replace them" and
  `packages.nix:18` says papirus is "used by rofi/dunst". Update both comments
  to swaync.
- **CL‑2 (ml4w):** the namespace/dir rename is **done** (state moved to
  `$XDG_STATE_HOME/desktop-nix`, DECISIONS 020). The only residue is the word
  "ml4w" in `hyprland.nix:212` and the docs (`tickets/04`, `INVENTORY.md:102`,
  `DECISIONS.md:300`). These are historical/ADR records — fine to leave in
  DECISIONS/INVENTORY as provenance, but the live code comment should drop it.
- **CL‑3 (hyprpicker):** installed + `layerrule "noanim, hyprpicker"` but no
  bind. Either add a bind (e.g. `SUPER+P → hyprpicker -a | wl-copy`) or drop
  the package + layerrule.
- **CL‑4 (smile):** float/pin/move rules for `it.mijorus.smile` but the app
  isn't installed and nothing launches it. Drop the rules (or install + bind
  it if an emoji picker is wanted — see QL‑3).
- **CL‑5 (browsers):** tiling rules for Microsoft-edge/Brave/Chromium; the
  actual browser is Zen and those aren't installed. Drop, or replace with a
  Zen rule if one is needed.
- **CL‑6 (CSS):** `waybar-style.css` carries `#custom-notification`,
  `#wireplumber.muted`, `#group-6/7/8` and a malformed `#window#waybar`
  selector from the original ml4w sheet — none match modules actually on the
  bar. Safe to prune.

> **Note:** `dotfiles-floating` (`hyprland.nix:262`) is **not** dead — it's the
> class `waybar.nix`'s `floatTop` helper launches (`--class dotfiles-floating`).
> Leave it. It is also the cleaned-up rename of the old ml4w floating class.

### 4.4 Quality / best-practice

- **QL‑1 (hardcoded colours):** the VPN connected/disconnected colours and the
  wlogout button colour are hardcoded hex (catppuccin), bypassing the stylix
  palette every other element uses. Map them to `@green`/`@red`/`@text` (waybar
  already prepends those defines) and the wlogout `@text`-equivalent.
- **QL‑2 (cursor):** `hyprland.nix:81,88` hardcode `Bibata-Modern-Ice`/size 24
  while the file header says cursor is owned by `stylix.cursor`. If the two
  ever diverge you get a cursor flip on session start. Derive from
  `config.stylix.cursor.{name,size}` or drop the exec-once and let stylix own
  it end-to-end.
- **QL‑3 (keymap gaps):** for a daily-driver, consider binds for the colour
  picker (resolves CL‑3), a clipboard history (`cliphist` + a rofi bind — not
  currently installed at all), a swaync toggle (`swaync-client -t -sw`), and a
  full-output screenshot to file (today only region/window → clipboard). A
  "cheat sheet" of binds (the dropped `keybindings.sh`) aids discoverability.
- **QL‑4 (waybar temperature):** no `hwmon-path`/`thermal-zone` → auto-detect.
  Verify on each host it reads a sensible sensor; pin per host if it picks a
  wrong/zero zone (ticket 04 flagged this for follow-up).
- **QL‑5 (minor):** kitty `scrollback_lines = 2000` is low; the `update` alias
  could be explicit about `#host`. Both cosmetic.

### 4.5 Host / cross-host consistency

- **HX‑1 (workspace→monitor):** kanshi pins output *geometry* (desktop DP‑3/DP‑2,
  work-laptop docked profiles) but nothing pins **workspaces to monitors**
  (e.g. `workspace = [ "1, monitor:DP-3" … ]`). Ticket 04 promised this "in
  tickets 13–15"; it never landed. waybar uses `all-outputs = true` +
  `persistent-workspaces."*" = 3`, so workspaces are shared across outputs —
  which may be the intent, but confirm it's deliberate rather than an omission,
  especially for the dual-head desktop.
- kanshi output names/modes (DP‑3/DP‑2, DP‑5/DP‑6, HDMI‑A‑1) are best-effort
  from the old `.conf` files and are **verify-on-hardware** (ticket 04 / 13–15
  note). The same applies to waybar temperature (QL‑4).

---

## 5. Positives (leave as-is)

- The runtime-mutation redesign is genuinely good: `hypr-focus-mode` uses
  `hyprctl keyword` + a writable `$XDG_STATE_HOME/desktop-nix` flag instead of
  rewriting a tracked config file; kanshi replaces the hotplug/env-switch
  scripts; obsolete scripts are documented as dropped in `pkgs/default.nix`.
- All desktop scripts use `writeShellApplication` (shellcheck + explicit
  `runtimeInputs`), handle no secrets, and degrade safely (`|| true`,
  empty-arg guards, clear `notify-send` failure paths). `hypr-move-to` and the
  wallpaper picker parse `hyprctl -j` via `jq` correctly (the SE‑1 kill bind is
  the one place that doesn't).
- stylix integration is consistent: per-app stylix targets are deliberately
  disabled where a custom layout is kept (hyprland/waybar/rofi/wlogout) and the
  base16 palette is re-injected — the seams are documented inline. The two
  hardcoded-colour spots (QL‑1) are the only leaks.
- The fish helpers were hardened during the port (`killf` uses `pgrep -f` with
  an empty-arg guard; `gst`/`extract` are self-contained); toolbox/fisher/tide
  residue was removed cleanly (`fish.nix` header documents what was retired).

---

## 6. Suggested order of work (if/when you fix)

1. **ST‑1** — remove the broken Hibernate button + alias (or add real swap).
   One-line UX/stability win.
2. **CL‑1…CL‑6** — the dead-config / ml4w-residue sweep (comments, orphaned
   rules/packages, dead CSS). Cheap, low-risk, and the core of your "cleanup".
3. **QL‑1/QL‑2** — fold the hardcoded colours + cursor back under stylix.
4. **SE‑1** — replace the `tr`-based kill with `hyprctl activewindow -j | jq .pid`.
5. **ST‑2/ST‑3** — per-host effect/idle trims (work-laptop battery, desktop
   suspend).
6. **GM‑1/GM‑2** — desktop gaming tuning (separate ticket; verify on hardware).
7. **QL‑3/QL‑4, HX‑1, SE‑2/SE‑3, QL‑5** — keymap gaps, sensor pinning,
   workspace pinning decision, and the conscious-decision security notes.

---

## 7. Open questions for you

These shape the *fix* pass (out of scope for this report-only audit) and are
worth deciding up front:

1. **Hibernate (ST‑1):** drop it entirely, or add encrypted swap so it works?
2. **Workspace→monitor (HX‑1):** is the shared "workspaces on all outputs"
   behaviour intentional, or do you want fixed workspace→output pinning on the
   dual-head desktop / docked work-laptop?
3. **Gaming profile (GM‑1/GM‑2):** appetite for a desktop-only "game mode"
   (tearing + VRR + effect drop), or keep the desktop on the shared profile for
   simplicity?
4. **Work-laptop effects (ST‑2):** acceptable to run a visibly lighter Hyprland
   profile on the work laptop for battery/thermals, or keep all three machines
   visually identical?
5. **Missing QoL tools (QL‑3):** do you want a clipboard manager (`cliphist`),
   an emoji picker (resurrect `smile` from CL‑4), and a colour-picker bind
   (CL‑3) added — or is the current minimal bind set deliberate?
