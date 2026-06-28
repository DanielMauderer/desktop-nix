# core

The machine-agnostic baseline, imported by **every** host (workstations via
`base`, the home-server directly). No desktop/GUI weight.

| File            | Configures                                                       |
|-----------------|-----------------------------------------------------------------|
| `boot.nix`      | systemd-boot, ESP at `/boot`, generation retention.             |
| `locale.nix`    | Timezone, locale, console.                                       |
| `networking.nix`| NetworkManager, hostname plumbing.                              |
| `nix.nix`       | Flakes, nix settings, GC, substituters/caches.                  |
| `users.nix`     | The `maudi` user, fish login shell, bootstrap password (below). |
| `packages.nix`  | Minimal system CLI package set.                                 |
| `secrets.nix`   | sops-nix wiring (scheme below).                                 |
| `updates.nix`   | `system.autoUpgrade` (automation below).                       |
| `hardening.nix` | nftables firewall, SSH off by default, kernel/sysctl hardening. |
| `audit.nix`     | Audit logging.                                                  |

## Secrets (sops-nix)

Secrets live encrypted in git as sops YAML. Each **host** decrypts with its SSH
host ed25519 key converted to age (`sops.age.sshKeyPaths`). A personal **master**
age key (private half in the password manager) is a recipient on every secret so
it can re-key and recover. Public keys and which paths encrypt to which recipients
live in `.sops.yaml`. Tooling (`sops`, `ssh-to-age`, `age`) is in the repo devShell.

- **One-time — master key:** `age-keygen -o master-age-key.txt`; store the private
  half in the password manager, put the public half in `.sops.yaml` as `&master`,
  delete the local file.
- **Per host install — enroll the host key:**
  ```sh
  cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age   # → age1…
  ```
  Replace that host's `age1PLACEHOLDER…` anchor in `.sops.yaml`, then
  `sops updatekeys secrets/<file>.yaml` for each secret the host must read.
  (Skip `secrets/fixtures/*` — those stay encrypted to the test key only.)
- **Add a secret:** `sops secrets/<file>.yaml` (path → recipients via
  `.sops.yaml` creation_rules), then reference
  `config.sops.secrets."<name>".path` from a module.
- **Rotate / recover:** edit + rebuild to rotate a value; on reinstall a host
  gets a new key — re-enroll (steps above) and drop the old anchor; a compromised
  master means new master key + `sops updatekeys` everything + rotate values.

Secrets decrypt at activation into `/run/secrets/<name>` (tmpfs, never the nix
store). The `test-secrets` nixosTest proves this end-to-end in `nix flake check`.

## Update automation

- `update-lock.yml` (daily CI) runs `nix flake update` → PR → auto-merges on
  green. Hosts run `system.autoUpgrade` daily (`allowReboot = false`) from the
  committed `flake.lock`.
- **Every host tracks the CI-gated `release` branch** (default in `updates.nix`),
  which only fast-forwards to a `main` commit whose full CI (flake-check + every
  per-host `build-hosts` job) is green (`promote-release.yml`) — so no host ever
  auto-pulls a revision that failed to build, even one landed by a direct push to
  `main`.
- **One-time repo setup:** create the `LOCKBUMP_TOKEN` fine-grained PAT (Contents
  + Pull requests: read/write) so bot PRs trigger CI; enable auto-merge; protect
  `main` requiring `nix flake check` + the per-host build checks; seed `release`
  (`git push origin main:release`).
- **First-login password:** every host ships a hashed throwaway password and
  force-expires it once at first activation (guarded by
  `/var/lib/nixos/.maudi-initial-pw-expired`), so `maudi` must set a real one.
  Change the hash in `users.nix` (`nix run nixpkgs#mkpasswd -- -m yescrypt`) or
  move it to sops (`hashedPasswordFile`) once host keys are enrolled.
