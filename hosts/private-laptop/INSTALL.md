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

## 3. Verify

- Wi-Fi, audio (`wpctl status`), Bluetooth, suspend/resume, brightness + volume
  keys, battery + power-profile waybar modules.
- Hyprland from greetd; swaync notifications; swaylock + auto-lock.
- New wallpaper re-themes GTK/Qt/kitty/waybar/rofi; `nvim :checkhealth` clean.
- `mpv` plays 4K with hardware decode (`vainfo` lists the iHD driver).
- Rollback drill: break something, `switch`, reboot, pick the prior generation.
