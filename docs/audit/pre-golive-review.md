# Pre-Go-Live Audit — `desktop-nix`

**Date:** 2026-06-16
**Scope:** Configuration audit (stability · security · quality) ahead of going live.
**Reviewer:** automated config audit (read-only; no config files were changed).
**Branch reviewed:** `claude/practical-galileo-jj81rz` @ `2e43485`.

> This is a **report only**. Nothing in the configuration was modified. Each
> finding has a severity, exact file references, and a recommendation for you to
> apply. Items that contradict a recorded decision in `docs/DECISIONS.md` are
> marked **(ADR change)** — they are flagged for your call, not assumed wrong.

---

## 1. Executive summary

The repository is in genuinely good shape. All three hosts **evaluate cleanly**
(`toplevel` eval exits 0, every `flake.nix` assertion passes) and **all 10
non-VM flake checks pass locally** (`statix`, `deadnix`, `nixfmt`, the three
`host-assertions-*`, and the four `dev-*` shells). The security baseline is
strong (SSH daemon off, root locked, nftables default-deny, auditd with sane
rules, sops-nix wired for activation-time decryption, LUKS2 on both laptops),
the module layout is clean, `with lib;` is absent, `mkForce` is used in only
three legitimate places, and the test/assertion coverage is unusually thorough.

There are **no correctness blockers** — nothing here prevents the machines from
building or booting. The findings that matter for *your* stated priorities are
concentrated in two areas:

- **Work-laptop high availability + compliance.** The daily
  auto-upgrade-from-`main` model on a `nixos-unstable` channel
  (**ST‑1**) and the fact that the upgrade mechanism does **not** actually pull
  new nixpkgs on its own (**ST‑2**) are the two items most in tension with
  "must not break unattended" and the §4.4 "security updates ≤ 72 h" claim.
- **Security go-live readiness.** The bootstrap password (**S‑1**) and the
  un-enrolled secrets/VPN (**S‑4**) are the gaps to close before the work
  laptop is relied upon.

### Go / no-go posture

| Host | Posture |
|---|---|
| **private-laptop** (pilot) | **GO** after P1s. Lowest stakes; ideal place to prove changes. |
| **desktop** (gaming) | **GO** after P1s + ST‑3/ST‑4 (keep a known-good fallback generation). Gaming stack is correctly desktop-isolated. |
| **work-laptop** (HA, policy-bound) | **Resolve ST‑1, ST‑2, S‑1, S‑4 first.** These are exactly the HA + compliance items the machine exists to satisfy. |

---

## 2. Methodology & scope

**In scope:** `flake.nix`, `flake.lock`, `lib/mkHost.nix`, all `hosts/**`, all
`modules/nixos/**`, the behavioural `modules/home/**` (lock screen/idle, dev
toolchains, shell wiring), `pkgs/scripts/**`, `.sops.yaml`, `secrets/**`,
`.github/workflows/ci.yml`, Stylix wiring, and the compliance/runbook docs as
they assert config guarantees.

**Excluded by request (not reviewed):** Hyprland config
(`modules/home/desktop/hyprland.nix`), Neovim (`nvim/**`,
`modules/home/neovim`), desktop *appearance* (waybar/rofi/wlogout/swaync
CSS/themes), CLI *appearance* (kitty/fastfetch/starship/lazygit/fish cosmetics),
and the ticket backlog.

**How it was checked:** direct read of every in-scope file; full `toplevel`
evaluation of all three hosts (runs every assertion); and a local build of the
non-VM flake checks. The QEMU/nixosTests (`test-*`) require `/dev/kvm`, which
this environment does not have, so those ~10 VM tests are **CI-only** here (they
run in `.github/workflows/ci.yml`). Raw commands and outputs are in the appendix.

---

## 3. Build / test baseline (evidence)

| Check | Where run | Result |
|---|---|---|
| `nix eval …work-laptop.toplevel.drvPath` | local | ✅ exit 0 (`nixos-system-work-laptop-26.11…`) |
| `nix eval …private-laptop.toplevel.drvPath` | local | ✅ exit 0 |
| `nix eval …desktop.toplevel.drvPath` | local | ✅ exit 0 (CachyOS closure resolves) |
| `statix-check`, `deadnix-check`, `nixfmt-check` | local | ✅ all pass (tree is lint/format/dead-code clean) |
| `host-assertions-{private-laptop,work-laptop,desktop}` | local | ✅ all pass (all `baseAssertions` + per-host deltas) |
| `dev-{node,python,go,rust}-check` | local | ✅ all pass |
| `test-*` nixosTests (boot, base, desktop, podman, libvirt, waydroid, gaming, secrets) | **CI only** | ⏳ not runnable locally (no `/dev/kvm`); covered by CI |
| Per-host `toplevel` **build** (full closure) | **CI only** | ⏳ deferred to CI `build-hosts` job (kernel/closures heavy) |

**Eval warnings observed** (all hosts, none fatal): `'system' renamed to
'stdenv.hostPlatform.system'`; `nixfmt-rfc-style is now the same as pkgs.nixfmt`;
`builtins.derivation … options.json … without a proper context`; and the nvim
`withRuby`/`withPython3` legacy-default notices. These map to Q‑1…Q‑4 below.

**`flake.lock` freshness:** inputs last modified 2026-06-06 … 2026-06-11 (≤ 10
days old at review). All inputs `follow` the top-level `nixpkgs` except
`chaotic` (which carries its own large transitive tree incl. jovian, niks3,
rust-overlay — expected for chaotic-nyx) and `hyprland` (pins its own nixpkgs —
typical, but adds a second nixpkgs to the eval).

---

## 4. Findings

Severity: **P0** = go-live blocker · **P1** = should fix before relying on the
machine · **P2** = nice-to-have / conscious-decision item. (No P0s were found.)

| ID | Severity | Cat | Host(s) | Finding | File |
|---|---|---|---|---|---|
| **ST‑1** | P1 | Stability | work-laptop (all) | Daily auto-upgrade from `main` on `nixos-unstable`, no pilot→prod staging; CI-gating can't catch runtime/hardware regressions **(ADR change)** | `modules/nixos/base/updates.nix:10` |
| **ST‑2** | P1 | Stability/Compliance | work-laptop (all) | `autoUpgrade` re-applies `main`'s committed `flake.lock`; it does **not** bump nixpkgs. §4.4 "≤72h" only holds if a human bumps the lock — no scheduled job exists | `modules/nixos/base/updates.nix`, `.github/workflows/ci.yml` |
| **ST‑3** | P2 | Stability | all | No `boot.loader.systemd-boot.configurationLimit`; GC `--delete-older-than 30d` bounds rollback by time, not by known-good count | `modules/nixos/base/boot.nix:4`, `nix.nix:17` |
| **ST‑4** | P2 | Stability | desktop | CachyOS kernel + `scx_lavd` arrive via the same daily auto-upgrade; a bad nyx bump could break boot unattended | `modules/nixos/gaming/kernel.nix:10` |
| **ST‑5** | P2 | Stability | all (esp. work-laptop) | zram-only → no hibernation; swayidle force-suspends at 10 min — can interrupt unattended work / the upgrade window | `modules/home/desktop/lockscreen.nix:31`, host `hardware.nix` |
| **ST‑6** | P2 | Stability | work-laptop | Zen Browser pinned to `twilight` (nightly) + daily upgrade = a moving primary work tool **(ADR 030)** | `modules/nixos/apps.nix:30` |
| **S‑1** | P1 | Security | all (esp. work-laptop) | `initialPassword = "changeme"` is weak **and lands in the world-readable Nix store**; `mutableUsers` unset (→ `true`). Code comment claims Ticket 12 replaced this — it didn't | `modules/nixos/base/users.nix:19` |
| **S‑4** | P1 | Security/Compliance | work-laptop | Secrets infra wired but inert: `.sops.yaml` recipients are `age1PLACEHOLDER…`, no production `sops.secrets`, WireGuard VPN (policy §4.5/4.6) still commented-out template | `.sops.yaml:15`, `hosts/work-laptop/default.nix:55` |
| **S‑2** | P2 | Security | all | `trusted-users = [ "root" "maudi" ]` → `maudi` is root-equivalent via the nix daemon | `modules/nixos/base/nix.nix:9` |
| **S‑3** | P2 | Security | work-laptop | Full libvirtd stack + autostarted `virbr0` NAT (dnsmasq, IP-forward) on the policy machine; `libvirtd` group is root-equivalent and `maudi` is in it **(ADR 028)** | `modules/nixos/virtualisation/libvirt.nix:14` |
| **S‑5** | P2 | Security | work-laptop | WireGuard template references `config` but the module signature is `{ lib, ... }:` → eval fails if uncommented verbatim during enrollment | `hosts/work-laptop/default.nix:62` |
| **S‑6** | P2 | Security | work-laptop | `bluetooth.powerOnBoot = true` fleet-wide; extra BT surface on the policy machine | `modules/nixos/base/audio.nix:18` |
| **S‑7** | P2 | Security | all | `qemu.runAsRoot = true` (default) — VM compromise = host root; note in the work-laptop threat model | `modules/nixos/virtualisation/libvirt.nix:24` |
| **Q‑1** | P2 | Quality | all | Eval warning: deprecated `system` attr → likely `pkgs.system` | `modules/nixos/apps.nix:30` |
| **Q‑2** | P2 | Quality | — | `nixfmt-rfc-style` now aliases `nixfmt` with a deprecation warning (3 refs) | `flake.nix:255,261,336` |
| **Q‑3** | P2 | Quality | all | Eval warning: `builtins.derivation … options.json … without a proper context` (likely Stylix/docs, upstream) | n/a (investigate) |
| **Q‑4** | P2 | Quality | all | nvim pulls Ruby+Python3 providers via legacy defaults (**out of scope**, but trivially silenced) | `modules/home/neovim` |
| **Q‑5** | P2 | Quality | laptops | `alsa.support32Bit = true` fleet-wide; only the gaming desktop needs it | `modules/nixos/base/audio.nix:11` |
| **Q‑6** | P2 | Quality | — | Stale comments: `users.nix:3` ("Ticket 12 replaces…" — not done); ADR 011 still says "weekly" (superseded by ADR 039 "daily", no cross-ref) | `modules/nixos/base/users.nix:3`, `docs/DECISIONS.md:139` |

---

## 5. Detail by priority

### 5.1 Work-laptop high availability (top priority)

**ST‑1 — Daily auto-upgrade from `main` on `nixos-unstable`, no staging.**
`system.autoUpgrade` (`updates.nix:10`) points every host — including the work
laptop — at `github:DanielMauderer/desktop-nix` (`main`) on a daily timer.
`allowReboot = false` is good (no surprise reboots; kernel/initrd changes wait
for a manual reboot). ADR 011 consciously accepts the risk and names CI-gating
of `main` as the mitigation, and ADR 039 raised the cadence weekly→daily for
the §4.4 window. The residual risk: **CI gating proves a host *builds*, not that
it *runs* correctly on real hardware** (Wi-Fi/dock/GPU regressions, a bad
service, a `nixos-unstable` papercut), and all three machines pull the same
`main` with no pilot→prod ordering — so the work laptop can break the same day
as the pilot.
*Recommendation (ADR change):* for `work-laptop`, pick one — (a) manual-only
(`system.autoUpgrade.enable = lib.mkForce false`, the one-liner ADR 011 already
anticipates) with a prompted weekly update; (b) stagger the work laptop a day
behind the private-laptop pilot; or (c) point work-laptop's `autoUpgrade.flake`
at a `release` branch/tag you fast-forward only after the pilot is healthy.

**ST‑2 — The upgrade mechanism doesn't actually pull new nixpkgs.**
`nixos-rebuild --flake github:…#host` (what `autoUpgrade` runs) builds from the
**flake.lock committed in `main`**; it refreshes the flake but does **not** run
`nix flake update`. So new nixpkgs (and security fixes) only reach hosts when
someone manually bumps the lock and merges. CI runs only `on: push`/`pull_request`
— there is no `schedule:`. The §4.4 / §4.5 "security updates ≤ 72 h" claim in
`docs/compliance/linux-workstation-policy.md` is therefore **process-dependent,
not mechanical**.
*Recommendation:* add a scheduled workflow (e.g. daily/weekly `nix flake update`
→ auto-PR, which CI then gates), or explicitly document the manual lock-bump
cadence as the control of record. Worth confirming the `autoUpgrade` lock
behaviour on a test host.

**ST‑3 / ST‑5 — Rollback & idle behaviour.** No `configurationLimit` means an
unbounded systemd-boot menu, and GC at 30 days bounds the rollback set by time
rather than by a count of known-good generations — exactly the safety net an HA
machine leans on after a bad upgrade. swayidle force-suspends at 10 min
(`lockscreen.nix:31`) on all hosts, which can interrupt an unattended task or
the randomized upgrade window. *Recommendation:* set `configurationLimit`
(~10–20); confirm the rollback story; consider a longer/disabled idle-suspend
on the work laptop.

**Positives (leave as-is):** LUKS2 full-disk (§4.2), nftables default-deny,
auditd + persistent journal, sudo `use_pty` + logfile, docked-kanshi profile
ordering (asserted), and the disko-not-imported-by-`default.nix` trick that
keeps VM tests off the real layout — all solid.

### 5.2 Desktop gaming (optimizations without sacrificing stability)

The gaming stack is **correctly isolated to the desktop**: `withChaotic = true`
only on `desktop` (`flake.nix:106`), and assertions prove the laptops carry no
scx/Steam/32-bit graphics and the desktop runs the CachyOS kernel + `scx_lavd`
(`flake.nix:399-518`). Steam (Proton-GE, gamescope, gamemode, remote-play
firewall), AMD RADV + 32-bit, LACT and MangoHud are all wired correctly and
desktop-scoped. The chaotic substituter is pinned with a trusted public key in
CI.

The one stability caveat is **ST‑4**: the bleeding-edge kernel reaches the box
through the same daily auto-upgrade, so a bad nyx bump could break boot
unattended. Keep a known-good fallback generation (ST‑3) and consider pinning
the kernel. The **unencrypted root** (`hosts/desktop/disk.nix`, ADR 038) is a
deliberate trade-off; restating the threat model for completeness: data at rest
is exposed if the machine is stolen or a disk is RMA'd — fine for an at-home box,
not for anything that leaves the house.

### 5.3 Cross-cutting security

**S‑1 (password)** and **S‑4 (secrets/VPN enrollment)** are the two go-live
security gaps — detailed in §4. For S‑1, the infra to fix it already exists:
set `users.users.maudi.hashedPasswordFile = config.sops.secrets.<name>.path`
(or `initialHashedPassword`) and make `mutableUsers` an explicit choice, so no
machine ships with a known store-readable password. S‑2/S‑3/S‑6/S‑7 are
conscious-decision items: on a policy-bound laptop, the value of `maudi` in
`trusted-users`, the always-on libvirtd + `virbr0`, BT-on-boot, and root QEMU
are each worth a deliberate "keep or trim" call against §4.6 "unneeded services
disabled." S‑5 is a small latent trap to fix at enrollment time.

**Positives:** the secrets design is genuinely good — activation-time decryption
(keyless CI builds every host), per-host SSH→age keys + a master key, test
fixtures encrypted to a throwaway key, and a nixosTest that proves `0400`
ownership and ciphertext-at-rest. The `pkgs/` scripts use `writeShellApplication`
(shellcheck + explicit `runtimeInputs`) and handle no secrets.

### 5.4 Nix quality & best practices

The tree passes `statix`/`deadnix`/`nixfmt` cleanly, avoids `with lib;`, uses
`mkDefault` for host-overridable values, and confines `mkForce` to three
legitimate uses (`claude.nix:39` + two sops test overrides). The remaining items
are cosmetic deprecations (**Q‑1…Q‑3**), an out-of-scope nvim closure trim
(**Q‑4**), a one-host-only option in base (**Q‑5**), and a couple of stale
comments (**Q‑6**). None affect behaviour; they're cheap wins for a tidy
go-live.

---

## 6. Respected decisions (not second-guessed)

These ADRs are treated as settled; findings that touch them are marked **(ADR
change)** so you decide:

- **005** nixos-unstable channel · **011/039** autoUpgrade from `main`, daily —
  ST‑1/ST‑2 ask you to revisit *only for the work laptop*, not to drop the model.
- **028** libvirt on all hosts (S‑3) · **030** Zen `twilight` (ST‑6) ·
  **034** desktop-only gaming stack · **038** unencrypted desktop (ST‑4 threat
  model) · **040** Waydroid opt-in (correctly absent from work-laptop).
- **022** Stylix theming, **015** greetd/tuigreet, **016** swaylock/swayidle,
  **027** devShells+direnv — all reviewed, no concerns.

---

## 7. Suggested order of work (if/when you fix)

1. **S‑1** managed password (closes a real go-live security gap; infra exists).
2. **ST‑2** automate or document the lock-bump (makes the §4.4 claim real).
3. **ST‑1** decide the work-laptop update model (the core HA call).
4. **S‑4** complete secrets + WireGuard enrollment (work-laptop compliance).
5. **ST‑3/ST‑4** `configurationLimit` + known-good fallback (rollback safety).
6. **Q‑1…Q‑6**, **S‑2/S‑3/S‑5/S‑6/S‑7**, **ST‑5/ST‑6** — batch cleanup / conscious-decision pass.

---

## Appendix — commands run & key outputs

```
# Capability probe
nix --version            → Determinate Nix 3.21.1 (Nix 2.34.7)
ls /dev/kvm              → absent  ⇒ nixosTests/VM checks are CI-only here
nproc / free -h          → 4 cores / 15 GiB

# Full host evaluation (runs every assertion) — ALL EXIT 0
nix eval --raw .#nixosConfigurations.work-laptop.config.system.build.toplevel.drvPath
  → /nix/store/…-nixos-system-work-laptop-26.11.20260606.a799d3e.drv   [exit 0]
nix eval --raw .#nixosConfigurations.private-laptop.…toplevel.drvPath  [exit 0]
nix eval --raw .#nixosConfigurations.desktop.…toplevel.drvPath         [exit 0]

# Non-VM flake checks — OVERALL EXIT 0 (all pass)
nix build --keep-going \
  .#checks.x86_64-linux.{statix-check,deadnix-check,nixfmt-check} \
  .#checks.x86_64-linux.host-assertions-{private-laptop,work-laptop,desktop} \
  .#checks.x86_64-linux.dev-{node,python,go,rust}-check
  → exit 0

# Eval warnings surfaced (→ Q-1..Q-4):
#   'system' has been renamed to 'stdenv.hostPlatform.system'
#   nixfmt-rfc-style is now the same as pkgs.nixfmt which should be used instead
#   builtins.derivation … options.json … without a proper context
#   programs.neovim.withRuby / withPython3 legacy-default notices
```

*VM nixosTests (`test-boot-private-laptop`, `test-base-system`, `test-desktop`,
`test-podman`, `test-virtualisation`, `test-waydroid`, `test-gaming`,
`test-secrets`) and full per-host `toplevel` builds were not run locally — no
`/dev/kvm` / heavy closures — and are covered by `.github/workflows/ci.yml`
(`flake-check` + `build-hosts`).*

---

## 8. Resolution status (2026-06-16)

Applied on branch `claude/laughing-edison-siwb0r`. Legend: **Fixed** (code
change), **Mitigated** (residual risk reduced + documented), **Kept** (conscious
decision, recorded in DECISIONS 046), **Deferred** (needs on-machine enrollment;
mechanism wired + runbook updated), **No action** (upstream / out of scope).

| ID | Status | What changed |
|---|---|---|
| **ST‑1** | Fixed | Per-host update channel: work-laptop tracks a CI-gated `release` branch; pilot/desktop stay on `main`. `updates.nix`, `hosts/work-laptop/default.nix`, routing assertion in `flake.nix`. DECISIONS 042 |
| **ST‑2** | Fixed | Scheduled daily `nix flake update` → PR → auto-merge on green (`.github/workflows/update-lock.yml`); promotion in `promote-release.yml`. The §4.4 window is now mechanical. DECISIONS 043 |
| **ST‑3** | Fixed | `boot.loader.systemd-boot.configurationLimit = 20` (`boot.nix`). DECISIONS 045 |
| **ST‑4** | Mitigated | configurationLimit keeps a known-good fallback for the CachyOS kernel; `allowReboot = false` means a bad kernel only bites on manual reboot. Pinning rejected (fights fast updates). DECISIONS 045 |
| **ST‑5** | Fixed | work-laptop auto-suspend 10 → 30 min (lock stays 5 min) so unattended work/updates aren't interrupted. `hosts/work-laptop/default.nix` |
| **ST‑6** | Kept | Zen `twilight` — user is comfortable with fast-moving software fleet-wide. DECISIONS 046 |
| **S‑1** | Fixed | `initialHashedPassword` (yescrypt hash, no store plaintext) + explicit `mutableUsers` + one-time forced first-login change. `users.nix`. DECISIONS 044 |
| **S‑2** | Kept | `trusted-users` keeps `maudi` — Docker/VM workflows depend on it. DECISIONS 046 |
| **S‑3** | Kept | libvirtd + `virbr0` NAT kept — Docker/VM workflows. DECISIONS 046 |
| **S‑4** | Deferred | Real age host keys + WireGuard key are enrolled on the machine (cannot be done in CI). Runbook updated (`runbooks/updates.md`, `secrets.md`); the S‑5 trap below is fixed |
| **S‑5** | Fixed | WireGuard template now instructs adding `config` to the module signature when uncommenting, so it can't eval-fail verbatim. `hosts/work-laptop/default.nix` |
| **S‑6** | Kept | `bluetooth.powerOnBoot = true` — the user's keyboard is Bluetooth; off-on-boot would lock them out. DECISIONS 046 |
| **S‑7** | Kept | `qemu.runAsRoot` kept — VM workflow. Threat model noted. DECISIONS 046 |
| **Q‑1** | Fixed | `pkgs.system` → `pkgs.stdenv.hostPlatform.system` (`apps.nix`) |
| **Q‑2** | Fixed | `nixfmt-rfc-style` → `nixfmt` ×3 (`flake.nix`) |
| **Q‑3** | No action | `options.json` context warning is upstream (Stylix), non-fatal |
| **Q‑4** | No action | nvim Ruby/Python providers — explicitly out of audit scope |
| **Q‑5** | Kept | `alsa.support32Bit` fleet-wide — harmless. DECISIONS 046 |
| **Q‑6** | Fixed | Stale `users.nix` comment removed; ADR 011 cross-referenced to 039/042/043 |
