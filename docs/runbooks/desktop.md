# desktop — install & migration runbook (Ticket 15)

The **last** machine to move from Fedora Silverblue (maudiblue) to NixOS, after
the private-laptop pilot ([Ticket 13](../tickets/13-host-private-laptop-pilot.md))
and the work-laptop ([Ticket 14](../tickets/14-host-work-laptop.md)). The gaming
stack ([Ticket 11](../tickets/11-gaming-and-cachyos-kernel.md)) gets its
real-hardware validation here — the CachyOS kernel + `scx_lavd` scheduler are
the whole point, so the performance pass (§8) matters.

Decisions for this host ([DECISIONS 038](../DECISIONS.md)):

- **Disk:** plain **ext4, no LUKS** (desktop at home — different physical-security
  profile than the laptops; no passphrase prompt at every boot). disko-managed
  GPT + 1 GiB ESP + ext4 root.
- **Steam library:** **fresh re-download** — no existing partition is preserved.
- **Boot:** **single-boot** — wipe Silverblue, install only NixOS. No dual-boot.
- **GPU/CPU:** **AMD** (mesa/RADV, `kvm-amd`, `amd-ucode`, `amdgpu` early KMS,
  `radeonsi` VAAPI). Confirm the exact model at §0.

Hostname stays `desktop`.

---

## 0. Hardware capture (do this first, on the running Silverblue system)

```sh
lscpu                         # CPU model + confirm AMD
lspci -nnk | grep -iA3 vga    # AMD dGPU model + driver (amdgpu / RADV)
lspci -nnk | grep -iA3 net    # network chip + firmware
lsblk -o NAME,SIZE,MODEL,TRAN # disk device (nvme0n1 vs sda) for disk.nix
ip link                       # interface names
hyprctl monitors              # confirm DP-3 / DP-2 output names + modes
```

If the disk is not `/dev/nvme0n1`: fix `device` in
[`hosts/desktop/disk.nix`](../../hosts/desktop/disk.nix).

If monitor output names differ from `DP-3` / `DP-2`: update the kanshi profile in
[`hosts/desktop/default.nix`](../../hosts/desktop/default.nix) and the positions
in the `host-assertions-desktop` `extraScript` in `flake.nix`. The expected
layout (from MyLinux `hypr/conf/monitors/default.conf`) is
`DP-3 = 2560x1440@144 @ 0,0` and `DP-2 = 1920x1080@60 @ 2560,0`.

---

## 1. Pre-migration backup checklist

This is a **wipe** — everything not in a backup or this repo is gone. Copy to
external storage and verify before formatting:

- [ ] **Non-cloud save games.** The Steam library is being **re-downloaded**, so
      Steam Cloud saves return automatically — but **list and back up the saves
      for titles without Steam Cloud** (and any emulator/standalone-launcher
      saves). Check each title's "Steam Cloud" indicator; copy local saves under
      `~/.local/share/Steam/steamapps/compatdata/<appid>/` or the game's own
      save directory.
- [ ] **libvirt VM images** (Ticket 09): copy `/var/lib/libvirt/images/*.qcow2`
      and `virsh dumpxml <domain>` for each domain you want to restore.
- [ ] **SSH:** `~/.ssh/` (private keys, `config`, `known_hosts`).
- [ ] **Git signing key:** confirm whether commits are signed and back up the key.
- [ ] **GPG / age:** `~/.gnupg/` and confirm the **sops master age key** is in
      the password manager (the single recovery root — see
      [secrets.md](secrets.md)).
- [ ] **Browser:** Zen Browser profile or export bookmarks + log into sync.
- [ ] **Documents / media:** inventory `~/` and copy what matters. Dotfiles and
      all config already live in this repo — nothing to copy there.

Write the inventory into this runbook's PR description so it is auditable.

---

## 2. Boot the installer

1. Download the **NixOS minimal ISO** (x86_64, unstable/latest) and write to USB:
   `dd if=nixos-minimal-*.iso of=/dev/sdX bs=4M status=progress; sync`
2. Boot the USB (disable Secure Boot if needed).
3. Networking: plug in ethernet (desktop) or `wpa_cli`. Confirm
   `ping -c1 cache.nixos.org`.

If anything on the Silverblue disk is not yet backed up, **image it first**
(`dd if=/dev/nvme0n1 of=/mnt/external/silverblue.img bs=4M status=progress`)
before §3 wipes it.

---

## 3. Partition + format with disko (no LUKS)

```sh
# Get the repo onto the installer.
nix-shell -p git --run 'git clone https://github.com/DanielMauderer/desktop-nix /tmp/cfg'

# CONFIRM the target device in disk.nix matches `lsblk` (nvme0n1 vs sda).
# This ERASES the disk. No LUKS, so no passphrase prompt.
sudo nix --experimental-features "nix-command flakes" run \
  github:nix-community/disko/latest -- \
  --mode disko /tmp/cfg/hosts/desktop/disk.nix
```

Verify with `lsblk` and `mount | grep /mnt` after it finishes.

---

## 4. Generate hardware config + install

```sh
# Generate WITHOUT filesystems — disko owns those.
sudo nixos-generate-config --no-filesystems --root /mnt

# Copy into the host dir.
sudo mkdir -p /tmp/cfg/hosts/desktop/hardware
sudo cp /mnt/etc/nixos/hardware-configuration.nix \
        /tmp/cfg/hosts/desktop/hardware/hardware-configuration.nix
```

Uncomment the `./hardware/hardware-configuration.nix` import in
[`hosts/desktop/default.nix`](../../hosts/desktop/default.nix). Reconcile its
`boot.initrd.availableKernelModules` / `boot.kernelModules` with `hardware.nix`
(drop duplicates — the generated probe wins; keep `kvm-amd`). Commit to the
working branch.

```sh
sudo nixos-install --flake /tmp/cfg#desktop --no-root-passwd
sudo nixos-enter --root /mnt -c 'passwd maudi'
reboot
```

On reboot: systemd-boot → greetd → Hyprland.

---

## 5. Post-install

```sh
# Clone to permanent location.
git clone https://github.com/DanielMauderer/desktop-nix ~/desktop-nix
```

### 5a. Secrets bootstrap

```sh
# Convert the host SSH key to an age public key.
cat /etc/ssh/ssh_host_ed25519_key.pub | nix run nixpkgs#ssh-to-age
```

Replace `age1PLACEHOLDERdesktopxxx…` in `.sops.yaml` with the output, then
re-encrypt the shared secrets so the desktop becomes a recipient:

```sh
cd ~/desktop-nix
# Update the master key placeholder too if not done yet (see docs/runbooks/secrets.md §1).
# Then re-key any shared secrets (secrets/*.yaml) to add the desktop:
# sops updatekeys secrets/<file>.yaml
```

### 5b. First managed rebuild

```sh
sudo nixos-rebuild switch --flake ~/desktop-nix#desktop
```

**Theming bootstrap:** stylix derives the palette from
`modules/nixos/desktop/wallpaper.png` at build time — nothing to seed by hand.

### 5c. Steam library + Proton

1. Launch **Steam**, log in. Steam Cloud saves sync automatically.
2. Re-download the games you want (fresh library — DECISIONS 038).
3. **GE-Proton** is declarative (`extraCompatPackages = [ proton-ge-bin ]`) —
   select "GE-Proton" under a title's Compatibility settings; no `protonup`.
4. Restore any **non-cloud saves** backed up in §1 into the title's
   `compatdata/<appid>/` or save directory.

---

## 6. Hardware + acceptance validation checklist

Run on the machine after first boot. These are the Ticket 15 acceptance gates.

### Base & desktop (from the pilot — re-verify)

- [ ] **Network** connects and survives a reboot
- [ ] **Audio** out + mic (`wpctl status`), volume keys
- [ ] **Hyprland** starts from greetd; waybar renders all modules
- [ ] **Notifications** (swaync) appear; **lock** (swaylock) works; auto-lock
      fires after idle
- [ ] **Wallpaper re-theme**: select a new wallpaper → GTK/Qt/kitty/waybar/rofi
      recolor
- [ ] **nvim** `:checkhealth` clean; LSP/treesitter load
- [ ] **Media**: `mpv` plays 4K with hardware decode (`vainfo` shows radeonsi)
- [ ] **App launches**: Zen Browser, Spotify, imv
- [ ] **Containers**: `podman run hello-world` succeeds
- [ ] **Dev devshells**: `cargo`, `go`, `node`, `python` on PATH in their
      respective `nix develop ~/desktop-nix#<lang>` shells; `docker` → podman

### Desktop / gaming-specific

- [ ] **CachyOS kernel**: `uname -r` contains `cachyos`
- [ ] **sched-ext**: `systemctl is-active scx` is active;
      `systemctl show -p Environment scx.service` shows `SCX_SCHEDULER=scx_lavd`
- [ ] **GPU / RADV**: `vulkaninfo | grep -i radv` shows the AMD RADV driver;
      `glxinfo | grep -i renderer` shows the AMD GPU
- [ ] **Monitors**: `hyprctl monitors` — DP-3 at **2560x1440@144** and DP-2 at
      **1920x1080@60**, positioned 0,0 and 2560,0 (kanshi `desktop` profile)
- [ ] **Steam library**: games install/launch; **a Proton title** and **a native
      title** both run
- [ ] **gamemode**: `gamemoded -s` responds; launching with `gamemoderun
      %command%` (or Steam launch option) toggles the governor during play
- [ ] **MangoHud**: overlay shows (e.g. `mangohud glxgears`, or per-title launch
      option), reading FPS/frametimes/GPU+CPU temps
- [ ] **LACT**: `lact` GUI opens, fan/clock/power controls respond (`lactd` up)
- [ ] **VMs**: a VM boots in virt-manager (restore the §1 qcow2 images)
- [ ] **Firewall**: `nft list ruleset` shows the filter table; SSH daemon not
      running (`systemctl is-active sshd` fails)
- [ ] **Rollback drill**: make a deliberately broken change, `switch`, reboot,
      pick the prior generation from systemd-boot, confirm boot, then roll back.

---

## 7. Rollback plan

- **Bad rebuild:** systemd-boot menu → prior generation, or
  `sudo nixos-rebuild switch --rollback`.
- **Install failure / emergency:** NixOS installer USB (re-run from §3). Keep it
  on the shelf.
- **No Silverblue fallback:** the Silverblue disk is being wiped (single-boot),
  so there is no SSD to swap back. Image it in §2 if you might need it.

---

## 8. Performance pass (the point of the CachyOS kernel)

Record MangoHud numbers so the kernel/scheduler change is **measurable**, not
just subjective. If possible, capture a baseline on Silverblue **before** the
wipe for the same titles:

- [ ] Pick 2–3 representative titles (one CPU-bound, one GPU-bound).
- [ ] For each: average + 1% low FPS and frametime from the MangoHud overlay
      (or `MANGOHUD_CONFIG=output_folder=...` logging), at the same settings.
- [ ] Note subjective input latency / stutter with `scx_lavd` active vs the old
      Silverblue kernel.
- [ ] Record the before/after numbers in this runbook's PR description (and below).

| Title | Silverblue (avg / 1% low) | NixOS + CachyOS (avg / 1% low) |
|-------|---------------------------|--------------------------------|
| _tbd_ | _tbd_                     | _tbd_                          |

---

## 9. Post-migration: backport lessons

After the machine is stable, file follow-ups against the relevant module tickets
for anything surfaced during migration (wrong output names in kanshi, missing
firmware, VAAPI driver mismatch, amdgpu quirks, scx regressions). Record decision
changes in [DECISIONS.md](../DECISIONS.md). This is the last migration — Ticket
17 (archive old repos) follows once all three machines are confirmed stable.
