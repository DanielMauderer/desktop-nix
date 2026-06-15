# Secrets bootstrap & key management

How the secrets scheme (Ticket 12 / [DECISIONS 035](../DECISIONS.md)) is set up
and how to bring a new host into it. Tooling (`sops`, `ssh-to-age`, `age`) is in
the repo devShell — run these from `nix develop ~/desktop-nix`.

Recap of the scheme: secrets live encrypted in git as sops YAML. Each **host**
decrypts with its own SSH host ed25519 key converted to age
(`sops.age.sshKeyPaths`). A personal **master** age key (private half in the
password manager) is a recipient on every production secret so it can re-key and
recover. Public keys + which paths encrypt to which recipients live in
[`.sops.yaml`](../../.sops.yaml).

## 1. One-time: create the master key

```sh
age-keygen -o master-age-key.txt
```

- Store the **private** half (`AGE-SECRET-KEY-1…`) in the password manager as a
  secure note. This is the recovery root — back it up; if it is lost, only the
  hosts can decrypt their own secrets.
- Put the **public** half (`age1…`) into `.sops.yaml` as the `&master` anchor,
  replacing the `age1PLACEHOLDERmaster…` placeholder. Delete the local file.

## 2. Per fresh host install: enroll the host key

After the host's first boot it has `/etc/ssh/ssh_host_ed25519_key`. Derive its
age public key:

```sh
# On the host (or over ssh): convert the public host key to age.
cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age
# -> age1…
```

Replace that host's `age1PLACEHOLDER…` anchor in `.sops.yaml`
(`&private_laptop` / `&work_laptop` / `&desktop`) with the value.

## 3. Re-key existing secrets for the new recipient

For every production secret the host must read, re-encrypt so the new recipient
is added (sops reads the updated `.sops.yaml` rules):

```sh
sops updatekeys secrets/<file>.yaml
# repeat per file, e.g. secrets/work-laptop/wireguard.yaml
```

Do **not** run this on `secrets/fixtures/*` — fixtures stay encrypted to the
test key only (the test VM cannot use a real host key).

## 4. Commit and rebuild

```sh
git add .sops.yaml secrets/
git commit -m "secrets: enroll <host>"
sudo nixos-rebuild switch --flake ~/desktop-nix#<host>
```

The host now decrypts its secrets at activation into `/run/secrets/<name>`
(tmpfs, never the nix store), with the owner/mode declared on each
`sops.secrets.<name>`.

## 5. Adding a new secret

```sh
# Path determines the recipients via .sops.yaml creation_rules.
sops secrets/<file>.yaml          # opens $EDITOR on the decrypted content
```

Then reference it from a module:

```nix
sops.secrets."<name>" = {
  sopsFile = ../secrets/<file>.yaml;   # or rely on a defaultSopsFile
  owner = "root";                       # or the consuming user
  mode = "0400";
};
# consume config.sops.secrets."<name>".path
```

## Rotation & recovery

- **Rotate a secret's value:** `sops secrets/<file>.yaml`, edit, save; rebuild.
- **Lost host key** (reinstall): the host gets a new SSH host key — repeat steps
  2–4 with the new age pubkey (and remove the old anchor).
- **Compromised master key:** generate a new master key, replace `&master`, then
  `sops updatekeys` every file, and rotate the secret values themselves.

## Verification

The `test-secrets` nixosTest (`nix flake check`) proves activation-time
decryption end to end against a committed fixture: it decrypts to
`/run/secrets`, checks owner/mode (`0400`), that a non-owner cannot read it, and
that the plaintext is absent from `/nix/store`.
