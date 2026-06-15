# private-laptop — install & migration runbook (PILOT)

The first machine to move from Fedora Silverblue (maudiblue) to NixOS
([Ticket 13](../tickets/13-host-private-laptop-pilot.md)). It is the pilot: the
lowest-risk machine (media + light dev), validating the whole module stack on
real hardware before work-laptop and desktop follow.

Decisions for this host ([DECISIONS 036](../DECISIONS.md)): **wipe** Silverblue
for a **full-disk** NixOS install, declarative partitioning with **disko**,
**LUKS** full-disk encryption, ext4 root, zram swap. Hostname stays
`private-laptop`. iGPU is **Intel** (VAAPI/QSV hardware decode).

---

## 0. Hardware capture (do this first, on the running Silverblue system)

The exact hardware is undocumented in the old repos. Record it before wiping —
it drives the iGPU/driver and disk-device choices:

```sh
lscpu                       # CPU + microcode (confirm Intel)
lspci -nnk | grep -iA3 vga  # iGPU model + kernel driver/VAAPI
lspci -nnk | grep -iA3 net  # wifi chip + driver/firmware
lsblk -o NAME,SIZE,MODEL,TRAN   # disk device (nvme0n1 vs sda) for disk.nix
ip link                     # interface names
```

If the iGPU is **pre-Broadwell** (Gen7 or older) switch `hardware.nix` from
`intel-media-driver` / `iHD` to `intel-vaapi-driver` / `i965`. If the disk is
not `/dev/nvme0n1`, fix `device` in
[`hosts/private-laptop/disk.nix`](../../hosts/private-laptop/disk.nix).

---

## 1. Pre-migration backup checklist

This is a **wipe**, so everything not in the repo or a backup is lost. Copy to
external storage and verify the copy opens before formatting:

- [ ] **Browser:** Zen Browser profile(s) — `~/.var/app/app.zen_browser.zen/`
      (Silverblue flatpak path). Or export bookmarks/passwords and sign into
      sync on the new machine.
- [ ] **SSH:** `~/.ssh/` (keys + `config` + `known_hosts`).
- [ ] **GPG / age:** any `~/.gnupg/`, and confirm the **sops master age key** is
      in the password manager (it is the recovery root — see
      [secrets.md](secrets.md)).
- [ ] **Credentials swept from `~/.config`:** the jira.nvim / gitlab.nvim API
      tokens and any app secrets (DECISIONS 035 flags these as machine-local).
- [ ] **Spotify:** nothing to back up (cloud); just note the login.
- [ ] **Media / documents:** inventory `~/` (Downloads, Documents, Pictures,
      any local media) and copy what matters.
- [ ] **dotfiles:** none needed — the config is this repo. Note any
      *uncommitted* local tweaks in the old MyLinux checkout.
- [ ] **Imperative state** the repos don't capture: ad-hoc flatpaks
      (`flatpak list --app`), GNOME keyring contents, manually-added fisher
      plugins (dropped — starship now, DECISIONS 023).

Write the `~/` inventory into this file's PR description so it is auditable.

---

## 2. Boot the installer

1. Download the **NixOS minimal ISO** (x86_64, unstable/latest) and write it to
   USB (`dd if=nixos-minimal-*.iso of=/dev/sdX bs=4M status=progress; sync`).
2. Boot the USB (disable Secure Boot if needed; this config does not set up
   Secure Boot).
3. Get networking up: `sudo systemctl start wpa_supplicant` then `wpa_cli`, or
   plug in ethernet. Confirm `ping -c1 cache.nixos.org`.

---

## 3. Partition + format with disko (LUKS)

disko reads the checked-in spec and does the partitioning, LUKS container,
formatting, and mounting under `/mnt` in one step.

```sh
# Get the repo onto the installer.
nix-shell -p git --run 'git clone https://github.com/DanielMauderer/desktop-nix /tmp/cfg'

# CONFIRM the target device in disk.nix matches `lsblk` (nvme0n1 vs sda).
# This ERASES the disk. disko prompts to set the LUKS passphrase.
sudo nix --experimental-features "nix-command flakes" run \
  github:nix-community/disko/latest -- \
  --mode disko /tmp/cfg/hosts/private-laptop/disk.nix
```

After it finishes, `/mnt` has the ext4 root (on `/dev/mapper/cryptroot`) and
`/mnt/boot` the ESP. Verify with `lsblk` and `mount | grep /mnt`.

---

## 4. Generate the hardware config + install

```sh
# Generate hardware-configuration.nix WITHOUT filesystems — disko owns those.
sudo nixos-generate-config --no-filesystems --root /mnt

# Move the generated hardware file into the host dir and drop the default config.
sudo mkdir -p /tmp/cfg/hosts/private-laptop/hardware
sudo cp /mnt/etc/nixos/hardware-configuration.nix \
        /tmp/cfg/hosts/private-laptop/hardware/hardware-configuration.nix
```

Then uncomment the `./hardware/hardware-configuration.nix` import in
[`hosts/private-laptop/default.nix`](../../hosts/private-laptop/default.nix).
Reconcile its `boot.initrd.availableKernelModules` with the baseline in
`hardware.nix` (drop duplicates; the generated probe wins). Commit this on the
working branch.

```sh
# Install. --no-root-passwd: maudi uses sudo; root login stays disabled.
sudo nixos-install --flake /tmp/cfg#private-laptop --no-root-passwd

# Set maudi's password (the config doesn't ship one).
sudo nixos-enter --root /mnt -c 'passwd maudi'

reboot
```

On reboot you should get the LUKS passphrase prompt, then greetd → Hyprland.

---

## 5. Post-install

```sh
# Clone the repo to its permanent home and enroll this host in secrets.
git clone https://github.com/DanielMauderer/desktop-nix ~/desktop-nix

# Secrets: convert the new host key to age and re-key (see secrets.md §2–4).
cat /etc/ssh/ssh_host_ed25519_key.pub | nix run nixpkgs#ssh-to-age
#   → paste into .sops.yaml &private_laptop, then `sops updatekeys` per file.

# First managed rebuild from the permanent checkout.
sudo nixos-rebuild switch --flake ~/desktop-nix#private-laptop
```

**Theming bootstrap:** stylix derives the palette from the wallpaper baked into
`modules/nixos/desktop/wallpaper.png` at build time — nothing to seed by hand.
To change it, the `theme-wallpaper-select` script copies the chosen image into
the state dir (`$XDG_STATE_HOME/desktop-nix`, DECISIONS 020) and re-themes.

---

## 6. Hardware validation checklist (acceptance test)

Run on the machine after first boot — this **is** the ticket's acceptance test:

- [ ] **Wi-Fi** connects (`nmtui`) and survives a reboot
- [ ] **Audio** out + mic (`pavucontrol` / `wpctl status`), volume keys
- [ ] **Bluetooth** pairs (waybar bluetooth → blueman)
- [ ] **Suspend/resume** (lid close + `systemctl suspend`) — display, wifi,
      audio all return
- [ ] **Brightness** keys (`XF86MonBrightness*` → brightnessctl) move the bar
- [ ] **Battery** waybar module shows charge + charging state; **power-profile**
      module toggles (power-profiles-daemon)
- [ ] **Hyprland** session starts from greetd; **waybar** renders all modules
- [ ] **Notifications** (swaync) appear; control center opens
- [ ] **Screenshot** (hyprshot) and **lock** (swaylock, then unlock via PAM)
- [ ] **Wallpaper re-theme**: select a new wallpaper → GTK/Qt/kitty/waybar/rofi
      recolor
- [ ] **nvim** `:checkhealth` is clean; LSP/treesitter load
- [ ] **Media**: `mpv` plays a 1080p/4K file with **hardware decode**
      (`vainfo` lists the iHD driver; `mpv --hwdec=auto` shows VAAPI in the log)
- [ ] **App launches**: Zen Browser, Spotify, imv
- [ ] **Containers/VMs** (light): `podman run` and `virsh -c qemu:///system list`

`nix flake check` (CI) already covers the headless slice: boots to
multi-user.target, greetd up, fish login, fonts, the desktop home generation,
and secrets decryption.

---

## 7. Rollback plan

- **Bad rebuild:** previous generations are in the systemd-boot menu — pick the
  prior generation at boot, or `sudo nixos-rebuild switch --rollback`.
- **Rollback drill (required by the ticket):** make a deliberately broken change
  (e.g. a typo'd unit), `switch`, reboot, and confirm the previous generation
  still boots from the menu. Then roll back.
- **Install went wrong / need Silverblue back:** the disk was wiped, so the
  fallback is the **NixOS installer USB** (re-run from §3) — keep it on the
  shelf. If you want a true escape hatch during the transition, image the
  Silverblue disk to external storage in §1 before wiping, or keep the old SSD
  un-erased on a shelf and swap it back.

---

## 8. Pilot lessons → feed back into the modules

After the machine is stable, file follow-ups against the relevant module tickets
for anything the pilot surfaced (wrong output names for kanshi, missing
firmware, VAAPI driver mismatch, power/suspend quirks). Record any decision
changes in [DECISIONS.md](../DECISIONS.md). Tickets 14/15 should start from the
corrected modules.
