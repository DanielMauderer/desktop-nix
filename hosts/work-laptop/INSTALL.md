# Installing `work-laptop`

Work laptop. **LUKS2 + ext4** full-disk encryption, WireGuard VPN, CI-gated
`release` channel. **Keep the old SSD un-wiped until the §4 gates pass.**

## 0. Before you wipe

Back up anything not in this repo or the cloud:
- Browser profile/bookmarks; `~/.ssh/` (incl. work identity files); git signing
  key; `~/.gnupg/`; Jira/GitLab tokens from `~/.config`; `~/.docker/config.json`;
  unpushed work branches; corporate CAs (`/etc/pki/ca-trust/source/anchors/`).
- **WireGuard private key** — export from the old machine / VPN portal; you paste
  it into sops in §3.
- Confirm the **sops master age key** is in the password manager (recovery root).

Capture hardware:
```sh
lsblk -o NAME,SIZE,MODEL,TRAN   # disk device for hosts/work-laptop/disk.nix
lspci -nnk | grep -iA3 vga      # Intel iGPU — verify iHD vs i965
hyprctl monitors                # confirm DP-5 / DP-6 / HDMI-A-1 names
```
Fix `device` in `disk.nix` if not `/dev/nvme0n1`; swap to `i965` in `hardware.nix`
for pre-Broadwell iGPUs; update the kanshi profiles in `default.nix` (and the
`host-assertions-work-laptop` script in `flake.nix`) if output names differ.

## 1. Install

Boot the **NixOS minimal ISO**, get networking up (`ping -c1 cache.nixos.org`):

```sh
nix-shell -p git --run 'git clone https://github.com/DanielMauderer/desktop-nix /tmp/cfg'
sudo /tmp/cfg/scripts/install.sh work-laptop
```

`install.sh` confirms the target disk, runs disko (**LUKS passphrase prompt**),
wires in `hardware-configuration.nix`, runs `nixos-install`, and prompts for
`maudi`'s password. Then `reboot` → LUKS passphrase → greetd → Hyprland.

## 2. Post-install + secrets

```sh
git clone https://github.com/DanielMauderer/desktop-nix ~/desktop-nix
cat /etc/ssh/ssh_host_ed25519_key.pub | nix run nixpkgs#ssh-to-age
# → replace age1PLACEHOLDERworklaptop… in .sops.yaml (full scheme: modules/nixos/core/README.md)
```

## 3. WireGuard VPN

```sh
cd ~/desktop-nix
sops edit secrets/work-laptop/wireguard.yaml   # wireguard-key: <paste private key>
sops updatekeys secrets/work-laptop/wireguard.yaml
```
In `hosts/work-laptop/default.nix` uncomment the `sops.secrets.wireguard-key` and
`networking.wg-quick.interfaces.wg0` blocks, add `config` to the module signature
(`{ lib, pkgs, config, ... }:`), and fill in the peer (endpoint, server pubkey,
allowed IPs, assigned address, DNS). Then:
```sh
sudo nixos-rebuild switch --flake ~/desktop-nix#work-laptop
sudo wg show          # interface + peer should appear
```

## 3b. Second WireGuard tunnel (`wg1`, from the provider wg.conf)

Independent of the home-server tunnel: `wg1` carries a full tunnel, `wg0` keeps
`10.100.0.0/24` (more specific, so it wins). Each device needs its **own**
keypair — the far end tracks one endpoint per public key, so a key shared
between machines means the last one to handshake steals the session.

```sh
cd ~/desktop-nix
# 1. Private key out of the provider config, into a per-host sops secret.
#    (The creation rule secrets/work-laptop/*.yaml already covers this filename.)
sops edit secrets/work-laptop/vpn.yaml       # vpn-wg-key: <the PrivateKey line of wg.conf>
sops updatekeys secrets/work-laptop/vpn.yaml
shred -u /path/to/wg.conf             # once its non-secret fields are copied over
```

Then in `hosts/work-laptop/default.nix`, fill `services.vpnClient` from the same
`wg.conf` — `address` = `Address`, `endpoint` = `Endpoint`, `publicKey` =
the peer's `PublicKey` — and uncomment `enable = true`. Non-defaults if the conf
disagrees: `allowedIPs` (defaults to a full tunnel) and `dns` (left empty on
purpose — setting it lets wg-quick rewrite `resolv.conf` and fight
systemd-resolved). Then:

```sh
sudo nixos-rebuild switch --flake ~/desktop-nix#work-laptop
sudo systemctl start wg-quick-wg1     # autostart is off by default
sudo wg show wg1                      # handshake within ~25 s
curl -s https://ifconfig.me           # exits via the tunnel
sudo systemctl stop wg-quick-wg1      # back to normal routing
ping 10.100.0.1                       # wg0 still up alongside it
```

## 4. Verify — "ready for Monday" gates (⛔ before wiping the old SSD)

- ⛔ Dual-external dock (DP-5 + DP-6, internal off) and single HDMI dock both work.
- ⛔ WireGuard tunnel up: `sudo wg show`, internal host reachable, internal DNS resolves.
- ⛔ Clone a representative work repo, `direnv allow`, build + tests **green**.
- ⛔ `cargo`/`go`/`node`/`python`/`gh` on PATH in their devshells; `docker` → podman.
- General: Wi-Fi/audio/Bluetooth/suspend/brightness; Hyprland + Noctalia; nvim with
  Jira/GitLab tokens re-entered; firewall on; rollback drill passes.

Add any corporate CAs to `security.pki.certificates` in `default.nix` if internal
services need them.
