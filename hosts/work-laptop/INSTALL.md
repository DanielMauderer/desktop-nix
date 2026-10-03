# Installing `work-laptop`

Work laptop. **LUKS2 + ext4** full-disk encryption, WireGuard VPN, CI-gated
`release` channel. **Keep the old SSD un-wiped until the §4 gates pass.**

## 0. Before you wipe

Already in this repo, encrypted to the master key only (`&work_laptop` is added
at §2): `secrets/work-laptop/vpn.yaml` (the full work WireGuard config, from
the Fedora NM `wg0` connection) and `secrets/work-laptop/user.yaml`
(`~/.ssh/id_ed25519` and the whole `~/.npmrc`). Keep company details (hosts,
IPs, registry IDs) inside sops — never in plaintext here. **Push them before wiping.**

Back up anything else not in this repo or the cloud: browser profile/bookmarks,
`~/.config/glab-cli/` token, `~/.docker/config.json`, unpushed work branches.
- ⛔ Prove the **sops master age key** from the password manager decrypts them —
  it is the only key that can until §2:
  `SOPS_AGE_KEY='AGE-SECRET-KEY-…' sops decrypt secrets/work-laptop/vpn.yaml >/dev/null && echo ok`

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

## 3. Enable the secrets (work VPN, SSH key, `.npmrc`)

`secrets/work-laptop/*.yaml` hold the VPN config, SSH key and `.npmrc`. Once the
host key is in `.sops.yaml`:

```sh
cd ~/desktop-nix
export SOPS_AGE_KEY='AGE-SECRET-KEY-…'   # master key, from the password manager
sops updatekeys secrets/work-laptop/vpn.yaml
sops updatekeys secrets/work-laptop/user.yaml
```

Set `enrolled = true;` at the top of `hosts/work-laptop/default.nix`, then:

```sh
sudo nixos-rebuild switch --flake ~/desktop-nix#work-laptop
ls -l ~/.ssh/id_ed25519 ~/.npmrc          # symlinks into /run/secrets, owned by maudi
sudo systemctl start wg-quick-wg1         # autostart is off by default
sudo wg show wg1                          # handshake within ~25 s
```

The tunnel is a full IPv4 tunnel (`wg1`); `wg0` stays reserved for the
home-server client. The old NM connection also set a VPN DNS server; if internal
names don't resolve, add a `DNS =` line to `vpn-wg-conf` (`sops edit`).

## 4. Verify — "ready for Monday" gates (⛔ before wiping the old SSD)

- ⛔ Dual-external dock (DP-5 + DP-6, internal off) and single HDMI dock both work.
- ⛔ WireGuard tunnel up: `sudo wg show`, internal host reachable, internal DNS resolves.
- ⛔ Clone a representative work repo, `direnv allow`, build + tests **green**.
- ⛔ `cargo`/`go`/`node`/`python`/`gh` on PATH in their devshells; `docker` → podman.
- General: Wi-Fi/audio/Bluetooth/suspend/brightness; Hyprland + Noctalia; nvim with
  Jira/GitLab tokens re-entered; firewall on; rollback drill passes.

Add any corporate CAs to `security.pki.certificates` in `default.nix` if internal
services need them.
