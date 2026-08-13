# Installing `private-laptop`

Personal laptop. **LUKS2 + ext4** full-disk encryption. Single boot — the disk
is wiped.

## 0. Before you wipe

Back up anything not in this repo or the cloud:
- Browser profile/bookmarks, `~/.ssh/`, `~/.gnupg/`, any API tokens in
  `~/.config` (jira.nvim / gitlab.nvim — machine-local), media/documents in `~/`.
- Confirm the **sops master age key** is in the password manager (recovery root).

Capture hardware on the running system:
```sh
lsblk -o NAME,SIZE,MODEL,TRAN   # disk device for hosts/private-laptop/disk.nix
lspci -nnk | grep -iA3 vga      # Intel iGPU model + VAAPI driver
```
If the disk isn't `/dev/nvme0n1`, fix `device` in `hosts/private-laptop/disk.nix`.
If the iGPU is pre-Broadwell (Gen7 or older), swap `intel-media-driver`/`iHD` for
`intel-vaapi-driver`/`i965` in `hardware.nix`.

## 1. Install

Boot the **NixOS minimal ISO**, get networking up (`wpa_cli` or ethernet;
`ping -c1 cache.nixos.org`), then:

```sh
nix-shell -p git --run 'git clone https://github.com/DanielMauderer/desktop-nix /tmp/cfg'
sudo /tmp/cfg/scripts/install.sh private-laptop
```

`install.sh` confirms the target disk, runs disko (**prompts to set the LUKS
passphrase**), generates and wires in `hardware-configuration.nix`, runs
`nixos-install`, and prompts for `maudi`'s password. Resume a stuck run with
`--skip-disko` / `--skip-hardware`. Then `reboot` (remove the USB) → LUKS
passphrase prompt → greetd → Hyprland.

## 2. Post-install

```sh
git clone https://github.com/DanielMauderer/desktop-nix ~/desktop-nix
```

**Secrets** — enroll this host (full scheme in
[modules/nixos/core/README.md](../../modules/nixos/core/README.md)):
```sh
cat /etc/ssh/ssh_host_ed25519_key.pub | nix run nixpkgs#ssh-to-age
# → replace age1PLACEHOLDER… for &private_laptop in .sops.yaml, then `sops updatekeys` each shared secret
sudo nixos-rebuild switch --flake ~/desktop-nix#private-laptop
```

## 2b. home-server VPN client (`ssh home-server` + the file share)

The `net` module is imported but `services.homeServerClient.enable` is off until
the box knows this peer. Server SSH is `wg0`-only, so the tunnel is what makes
both SSH and the NFS mount reachable. One-time enrollment:

```sh
cd ~/desktop-nix
# 1. Generate this host's WireGuard keypair (private half → sops, public → server)
wg genkey | tee /tmp/wg.key | wg pubkey       # note the printed PUBLIC key
# 2. Store the private key as a per-host secret (age key already enrolled in §2)
sops edit secrets/private-laptop/wireguard.yaml   # home-server-wg-key: <paste /tmp/wg.key>
sops updatekeys secrets/private-laptop/wireguard.yaml
shred -u /tmp/wg.key
```

Then one-time server/module edits (commit them):
- `modules/nixos/server/wireguard.nix` — uncomment the private-laptop peer, paste
  the PUBLIC key from step 1 (`allowedIPs = [ "10.100.0.3/32" ]`).
- `modules/nixos/net/home-server-client.nix` — fill the `endpoint`,
  `serverPublicKey` (server's `wg show` pubkey) and `serverHostKey`
  (`cat /etc/ssh/ssh_host_ed25519_key.pub` on the server) defaults. Shared by
  every client, so this is done once.
- `hosts/private-laptop/default.nix` — set `services.homeServerClient.enable = true`.

Rebuild the **server first** (so the peer is admitted), then this host:
```sh
sudo nixos-rebuild switch --flake ~/desktop-nix#private-laptop
sudo wg show                       # handshake with 10.100.0.1 within ~25 s
ssh home-server                    # no host/IP/TOFU prompt
ls /mnt/home-server                # triggers the automount
```

This host tunnels to the *name* `vpn.mauderer.work`, whose address changes with
every reconnect at the server's end, so it also runs `wg0-reresolve.timer` — a
minutely check that re-resolves the endpoint once the peer's last handshake is
older than 150 s. `systemctl list-timers wg0-reresolve` should list it, and
`journalctl -u wg0-reresolve` is where a tunnel that keeps going quiet after the
server reconnects will show up. Nothing is logged while the tunnel is healthy;
the unit exits early.

## 2c. Second WireGuard tunnel (`wg1`, from the provider wg.conf)

Independent of the home-server tunnel: `wg1` carries a full tunnel, `wg0` keeps
`10.100.0.0/24` (more specific, so it wins). Each device needs its **own**
keypair — the far end tracks one endpoint per public key, so a key shared
between machines means the last one to handshake steals the session.

```sh
cd ~/desktop-nix
# 1. Private key out of the provider config, into a per-host sops secret.
#    (The creation rule secrets/private-laptop/*.yaml already covers this filename.)
sops edit secrets/private-laptop/vpn.yaml       # vpn-wg-key: <the PrivateKey line of wg.conf>
sops updatekeys secrets/private-laptop/vpn.yaml
shred -u /path/to/wg.conf             # once its non-secret fields are copied over
```

Then in `hosts/private-laptop/default.nix`, fill `services.vpnClient` from the same
`wg.conf` — `address` = `Address`, `endpoint` = `Endpoint`, `publicKey` =
the peer's `PublicKey` — and uncomment `enable = true`. Non-defaults if the conf
disagrees: `allowedIPs` (defaults to a full tunnel) and `dns` (left empty on
purpose — setting it lets wg-quick rewrite `resolv.conf` and fight
systemd-resolved). Then:

```sh
sudo nixos-rebuild switch --flake ~/desktop-nix#private-laptop
sudo systemctl start wg-quick-wg1     # autostart is off by default
sudo wg show wg1                      # handshake within ~25 s
curl -s https://ifconfig.me           # exits via the tunnel
sudo systemctl stop wg-quick-wg1      # back to normal routing
ping 10.100.0.1                       # wg0 still up alongside it
```

## 3. Verify

- Wi-Fi, audio (`wpctl status`), Bluetooth, suspend/resume, brightness + volume
  keys (Noctalia OSD), battery + power-profile widgets in the Noctalia bar.
- Hyprland from greetd; Noctalia bar/launcher/notifications; lock + auto-lock.
- Pick a wallpaper (SUPER+W); `SUPER+SHIFT+W` syncs it so GTK/Qt/kitty re-theme;
  `nvim :checkhealth` clean.
- `mpv` plays 4K with hardware decode (`vainfo` lists the iHD driver).
- Rollback drill: break something, `switch`, reboot, pick the prior generation.
