# Installing `desktop`

Gaming + dev workstation. **LUKS2 + ext4** full-disk encryption (passphrase at
boot, like the laptops). Single boot — the disk is wiped.

## 0. Before you wipe

Back up anything not in this repo or the cloud:
- Non-Steam-Cloud save games and emulator saves; libvirt VM images
  (`/var/lib/libvirt/images/*.qcow2` + `virsh dumpxml <domain>`).
- `~/.ssh/`, git signing key, `~/.gnupg/`, browser profile/bookmarks.
- Confirm the **sops master age key** is in the password manager (recovery root).

Capture hardware on the running system (drives `disk.nix` / kanshi):
```sh
lsblk -o NAME,SIZE,MODEL,TRAN   # disk device for hosts/desktop/disk.nix
lspci -nnk | grep -iA3 vga      # confirm AMD dGPU
hyprctl monitors                # confirm DP-3 / DP-2 names + modes
```
If the disk isn't `/dev/nvme0n1`, fix `device` in `hosts/desktop/disk.nix`. If
the outputs differ from `DP-3`/`DP-2`, update the kanshi profile in
`hosts/desktop/default.nix` and the `host-assertions-desktop` script in `flake.nix`.

## 1. Install

Boot the **NixOS minimal ISO**, get networking up (`ping -c1 cache.nixos.org`),
then:

```sh
nix-shell -p git --run 'git clone https://github.com/DanielMauderer/desktop-nix /tmp/cfg'
sudo /tmp/cfg/scripts/install.sh desktop
```

`install.sh` confirms the target disk, runs disko (**LUKS passphrase prompt**),
generates and wires in `hardware-configuration.nix`, runs `nixos-install`, and
prompts for `maudi`'s password. Resume a stuck run with `--skip-disko` (after
partitioning) or `--skip-hardware`. Then `reboot` (remove the USB) → systemd-boot
→ LUKS passphrase → greetd → Hyprland.

## 2. Post-install

```sh
git clone https://github.com/DanielMauderer/desktop-nix ~/desktop-nix
```

**Secrets** — enroll this host (full scheme in
[modules/nixos/core/README.md](../../modules/nixos/core/README.md)):
```sh
cat /etc/ssh/ssh_host_ed25519_key.pub | nix run nixpkgs#ssh-to-age
# → replace age1PLACEHOLDERdesktop… in .sops.yaml, then `sops updatekeys` each shared secret
sudo nixos-rebuild switch --flake ~/desktop-nix#desktop
```

## 2b. home-server VPN client (`ssh home-server` + the file share)

The `net` module is imported but `services.homeServerClient.enable` is off until
the box knows this peer. This host is always home, so the share mounts **direct
over the LAN** (`nfsHost` in `default.nix` — set it to the server's LAN IP); SSH
still rides the tunnel (server SSH is `wg0`-only). Enroll the desktop age key in
§2 **first** — `&desktop` in `.sops.yaml` is a placeholder, so sops can't encrypt
a per-host secret until it is real. Then:

```sh
cd ~/desktop-nix
wg genkey | tee /tmp/wg.key | wg pubkey            # note the printed PUBLIC key
sops edit secrets/desktop/wireguard.yaml           # home-server-wg-key: <paste /tmp/wg.key>
sops updatekeys secrets/desktop/wireguard.yaml
shred -u /tmp/wg.key
```

One-time server/module edits (commit them):
- `modules/nixos/server/wireguard.nix` — uncomment the desktop peer, paste the
  PUBLIC key (`allowedIPs = [ "10.100.0.2/32" ]`).
- `modules/nixos/net/home-server-client.nix` — fill `endpoint`, `serverPublicKey`,
  `serverHostKey` (shared by every client; skip if a laptop already did it).
- `hosts/desktop/default.nix` — set the real `nfsHost` LAN IP and
  `services.homeServerClient.enable = true`.

Rebuild the **server first**, then this host:
```sh
sudo nixos-rebuild switch --flake ~/desktop-nix#desktop
sudo wg show && ssh home-server && ls /mnt/home-server
```

**Steam** — launch Steam, log in (Cloud saves sync), re-download games. GE-Proton
is declarative (`extraCompatPackages`) — select it under a title's Compatibility
settings. Restore non-cloud saves into `compatdata/<appid>/`.

## 3. Verify

- `uname -r` contains `cachyos`; `systemctl is-active scx` and `SCX_SCHEDULER=scx_lavd`.
- `vulkaninfo | grep -i radv` shows the AMD driver.
- `hyprctl monitors` — DP-3 @ 2560x1440@144, DP-2 @ 1920x1080@60.
- A Proton title and a native title both launch; MangoHud overlay and LACT work.
- Rollback drill: break something, `switch`, reboot, pick the prior generation.
