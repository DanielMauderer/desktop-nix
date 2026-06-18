# Installing `home-server`

Headless services host. **No GUI** — administered over SSH (VPN-only). disko owns
**only the OS SSD** (ext4, no LUKS, unattended boot); the pre-existing **ZFS data
pool** on the RAID LUN is imported at runtime and is never touched by the install.

## 0. Before you install

- **Enroll your SSH key first.** SSH is key-only and the box is headless — if you
  don't add a key you'll lock yourself out. Put your public key in
  `users.users.maudi.openssh.authorizedKeys.keys` in
  `hosts/home-server/default.nix` and commit it before installing.
- Verify the **OS SSD** device in `hosts/home-server/disk.nix` (`lsblk` — usually
  `/dev/nvme0n1`). **Make sure it is NOT the RAID LUN that holds the ZFS pool.**
- Note the ZFS pool name (`zfs.extraPools` in `modules/nixos/server/zfs.nix`,
  default `tank`) and edit the LAN subnet in `modules/nixos/server/nfs.nix`.
- Confirm the **sops master age key** is in the password manager.

## 1. Install

Boot the **NixOS minimal ISO**, get networking up (`ping -c1 cache.nixos.org`):

```sh
nix-shell -p git --run 'git clone https://github.com/DanielMauderer/desktop-nix /tmp/cfg'
sudo /tmp/cfg/scripts/install.sh home-server
```

`install.sh` confirms the target disk, runs disko (no LUKS), wires in
`hardware-configuration.nix`, runs `nixos-install`, and prompts for `maudi`'s
password. Reconcile the `hostId` in `hardware.nix` (ZFS needs a unique one). Then
`reboot` — it comes up headless to multi-user; log in over SSH.

## 2. Post-install

```sh
git clone https://github.com/DanielMauderer/desktop-nix ~/desktop-nix
```

**Secrets** — enroll this host (full scheme in
[modules/nixos/core/README.md](../../modules/nixos/core/README.md)):
```sh
cat /etc/ssh/ssh_host_ed25519_key.pub | nix run nixpkgs#ssh-to-age
# → replace the home-server age1PLACEHOLDER… in .sops.yaml, then `sops updatekeys`
```

**WireGuard server** — generate the server key on the box (kept out of git/CI):
```sh
sudo sh -c 'umask 077; wg genkey > /etc/wireguard/wg0.key'
```
Add each client's **public** key (non-secret) to `peers` in
`modules/nixos/server/wireguard.nix`, then:
```sh
sudo nixos-rebuild switch --flake ~/desktop-nix#home-server
```

## 3. Verify

- SSH reachable **only over the VPN** (`wg show`; port 22 closed on the WAN).
- ZFS pool imported: `zpool status` shows the data pool; `zfs list`.
- NFS export reachable from the LAN/VPN only: `showmount -e <server>`.
- Firewall: only UDP 51820 open on the WAN (`nft list ruleset`).
- Rollback drill: break something, `switch`, reboot, pick the prior generation.
