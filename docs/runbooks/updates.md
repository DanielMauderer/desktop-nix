# Updates, release promotion & first-login password

How the fleet stays current and how the work-laptop's protected channel works
(audit ST-1/ST-2, [DECISIONS 042/043/044](../DECISIONS.md)). Read this once
when setting up the repo's automation; day to day it runs itself.

## The model in one picture

```
 nixpkgs moves
      │
      ▼
 update-lock.yml (daily schedule)   nix flake update → PR → auto-merge on green
      │
      ▼
   main ───────────────────────────► private-laptop (pilot) + desktop
      │   (CI: flake check + build-hosts)        system.autoUpgrade, daily
      │
      ▼  promote-release.yml (on CI success on main)
  release ──────────────────────────► work-laptop
                                            system.autoUpgrade, daily
```

- **private-laptop (pilot) + desktop** track `main` — fastest.
- **work-laptop** tracks `release`, which only ever fast-forwards to a `main`
  commit whose `build-hosts` CI is green. Build-gated, no time delay.
- All hosts run `system.autoUpgrade` **daily** with `allowReboot = false`
  (kernel/initrd changes apply on the next manual reboot).
- `autoUpgrade` rebuilds from the **committed** `flake.lock`; the thing that
  actually advances nixpkgs is `update-lock.yml`, not the timer.

## One-time setup (required before the automation works)

1. **`LOCKBUMP_TOKEN` secret.** Create a *fine-grained PAT* scoped to this repo
   with **Contents: read/write** and **Pull requests: read/write**, and add it as
   the repo secret `LOCKBUMP_TOKEN` (Settings → Secrets and variables → Actions).
   A PAT is required because PRs/pushes made with the default `GITHUB_TOKEN` do
   **not** trigger `on: pull_request` / `on: push` workflows — so without it the
   bot PR's CI never starts and auto-merge never fires.
2. **Allow auto-merge.** Settings → General → Pull Requests → "Allow auto-merge".
3. **Protect `main`.** Settings → Branches → add a rule for `main` requiring the
   status checks **`nix flake check`** and **`Build private-laptop` / `Build
   work-laptop` / `Build desktop`**. This makes auto-merge wait for green.
4. **Seed `release`.** It is created automatically on the first
   `promote-release` run, or seed it manually:
   ```sh
   git push origin main:release
   ```
   The work-laptop's `autoUpgrade` fails until `release` exists, so do this
   before relying on the work laptop.

## Everyday operation

- Nothing to do. `update-lock.yml` runs daily, opens/refreshes the
  `automation/flake-lock` PR, and it auto-merges when CI is green; `main` and (on
  green) `release` advance; hosts pull on their daily timer.
- **Force an update now:** Actions → `update-lock` → "Run workflow". Then, if
  needed, on a host: `sudo nixos-rebuild switch --flake github:DanielMauderer/desktop-nix#<host>`
  (work-laptop uses `…/desktop-nix/release#work-laptop`).
- **A bad upgrade landed:** reboot and pick an earlier generation from the
  systemd-boot menu (the last 20 are kept — DECISIONS 045), then roll the flake
  back / pin as needed.
- **Promote manually** (e.g. to re-seed `release`): Actions → `promote-release`
  → "Run workflow" on `main`.

## First-login password (DECISIONS 044)

Every host ships a **hashed** throwaway bootstrap password (no plaintext in the
Nix store) and force-expires it once at first activation, so `maudi` must set a
real password at first login. The `chage -d 0` is guarded by
`/var/lib/nixos/.maudi-initial-pw-expired`, so rebuilds never re-expire a
password you have since set.

- **Change the bootstrap hash** (recommended before first install) — generate
  your own and replace the literal in `modules/nixos/base/users.nix`:
  ```sh
  nix run nixpkgs#mkpasswd -- -m yescrypt   # paste into initialHashedPassword
  ```
- **Or move it into sops** once host keys are enrolled (`secrets.md`): add a
  secret holding the yescrypt hash and set
  `users.users.maudi.hashedPasswordFile = config.sops.secrets.<name>.path;`
  (drop `initialHashedPassword`). This needs the real host age keys, so it
  cannot be validated in CI — do it on the machine.

## See also

- [`secrets.md`](secrets.md) — enrolling host age keys, the WireGuard key (audit
  S-4); the WireGuard template in `hosts/work-laptop/default.nix` needs `config`
  added to its module signature when uncommented (audit S-5, noted inline).
- [`compliance-tasks.md`](compliance-tasks.md) — the §4.4 monthly update
  confirmation.
