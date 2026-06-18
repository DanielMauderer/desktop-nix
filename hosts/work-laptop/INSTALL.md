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

## 4. Verify — "ready for Monday" gates (⛔ before wiping the old SSD)

- ⛔ Dual-external dock (DP-5 + DP-6, internal off) and single HDMI dock both work.
- ⛔ WireGuard tunnel up: `sudo wg show`, internal host reachable, internal DNS resolves.
- ⛔ Clone a representative work repo, `direnv allow`, build + tests **green**.
- ⛔ `cargo`/`go`/`node`/`python`/`gh` on PATH in their devshells; `docker` → podman.
- General: Wi-Fi/audio/Bluetooth/suspend/brightness; Hyprland + waybar; nvim with
  Jira/GitLab tokens re-entered; firewall on; rollback drill passes.

Add any corporate CAs to `security.pki.certificates` in `default.nix` if internal
services need them.
