# Installing `home-server`

Headless services host, installed **remotely with nixos-anywhere** (no ISO
juggling on a box with no display). disko owns **only the OS SSD** (ext4, no
LUKS, unattended boot); the pre-existing **ZFS data pool** on the RAID LUN is
imported at runtime and is never touched by the install.

Because the server holds real secrets (its WireGuard key), its age identity must
exist **before** first boot. We do that by pre-generating the SSH host key and
pushing it in during the install (`--extra-files`), so sops decrypts on first
boot — no after-the-fact key enrollment.

## 0. Already prepared (committed to the repo)

The secrets-first work is done and in git:

- Admin SSH key authorized in `default.nix` (`maudi@desktop`).
- Server age key enrolled in `.sops.yaml`; WireGuard server key encrypted in
  `secrets/home-server/wireguard.yaml`.
- Client keys in `secrets/{desktop,private-laptop}/wireguard.yaml`; their public
  keys wired into `peers` (`modules/nixos/server/wireguard.nix`) and the server's
  public/host keys into the client module (`modules/nixos/net/home-server-client.nix`).
- The matching **plaintext** SSH host key + WireGuard keys are in the gitignored
  `secrets-seed/` on the desktop (used for `--extra-files` below). Keep it until
  the install succeeds.

## 1. Check before you install

- **OS SSD device** in `hosts/home-server/disk.nix` (`lsblk` on the target —
  usually `/dev/nvme0n1`). **Must NOT be the RAID LUN that holds the ZFS pool.**
- **ZFS `hostId`** in `hardware.nix` is unique; ZFS pool name (`zfs.extraPools`,
  default `tank`) and the LAN subnet in `modules/nixos/server/nfs.nix`.
- **`nfsHost`/LAN IP** for the desktop client in `hosts/desktop/default.nix`.
- **sops master age key** is in the password manager.
- **DNS:** `vpn.mauderer.work` must be a **DNS-only (grey-cloud)** Cloudflare
  record → the WAN IP. Cloudflare's proxy does not carry WireGuard's UDP/51820.

## 2. Boot the target into an installer

Get the box onto the network in an environment nixos-anywhere can SSH into as
root — the NixOS minimal ISO (set a root password + start `sshd`) or a kexec
image. Note its IP (`<ip>`). Uncomment the hardware import in
`hosts/home-server/default.nix`:

```nix
./hardware/hardware-configuration.nix
```

## 3. Run nixos-anywhere (from the desktop, in the repo)

```sh
nix run github:nix-community/nixos-anywhere -- \
  --flake .#home-server \
  --generate-hardware-config nixos-generate-config ./hosts/home-server/hardware/hardware-configuration.nix \
  --extra-files ./secrets-seed \
  root@<ip>
```

- `--generate-hardware-config` probes the target and writes the real
  `hardware-configuration.nix` into the host dir (stage it — `git add -N
  hosts/home-server/hardware/` — if the flake build says it's untracked).
- disko (`hosts/home-server/disk.nix`) partitions the OS SSD; the ZFS LUN is
  untouched.
- `--extra-files ./secrets-seed` lands the pre-generated
  `/etc/ssh/ssh_host_ed25519_key`; the activation script in
  `modules/nixos/core/secrets.nix` keeps it (only generates one when absent), so
  the host's age identity matches `.sops.yaml`.

The box reboots into the installed system. On first boot sops decrypts the
WireGuard key with the seeded identity.

## 4. Post-install

```sh
git clone https://github.com/DanielMauderer/desktop-nix ~/desktop-nix
sudo passwd maudi           # set a real password (config ships none)
```

Enable the clients **last**, once the server is reachable: uncomment
`services.homeServerClient.enable = true;` in `hosts/desktop/default.nix` and
`hosts/private-laptop/default.nix`, then `update` on each.

## 5. Verify

- On the server: `journalctl -u sops-nix` shows the WireGuard key decrypted;
  `wg show` lists `wg0` with the two client peers.
- SSH reachable **only over the VPN** (port 22 closed on the WAN); from an
  enabled client `ssh home-server` has no TOFU prompt (host key pinned).
- `zpool status` / `zfs list` show the data pool; `showmount -e <server>` lists
  the export; `nft list ruleset` shows only UDP 51820 open on the WAN.
- Once verified, delete `secrets-seed/` on the desktop.
- Rollback drill: break something, `switch`, reboot, pick the prior generation.
