# work-laptop — install & migration runbook (Ticket 14)

The second machine to move from Fedora Silverblue (maudiblue) to NixOS, after
the private-laptop pilot ([Ticket 13](../tickets/13-host-private-laptop-pilot.md),
runbook: [private-laptop.md](private-laptop.md)). The pilot validated the module
stack on real hardware; lessons from it feed into the shared modules before this
machine is touched.

Decisions for this host ([DECISIONS 037](../DECISIONS.md)): same **disko +
LUKS2 + ext4 + zram** layout as the pilot, **Intel iGPU** (verify model at
§0), **WireGuard** VPN via `wg-quick` + sops-nix. Hostname stays
`work-laptop`. Migration scheduled outside work hours; "Ready for Monday" gate
(§6) must pass before the old SSD is wiped.

---

## 0. Hardware capture (do this first, on the running Silverblue system)

```sh
lscpu                        # CPU model + confirm Intel
lspci -nnk | grep -iA3 vga   # iGPU model + driver — verify iHD vs i965
lspci -nnk | grep -iA3 net   # wifi chip + firmware
lsblk -o NAME,SIZE,MODEL,TRAN # disk device (nvme0n1 vs sda) for disk.nix
ip link                      # interface names
hyprctl monitors              # confirm DP-5 / DP-6 / HDMI-A-1 output names
```

If the iGPU is **pre-Broadwell** (Gen7 or older): in
[`hosts/work-laptop/hardware.nix`](../../hosts/work-laptop/hardware.nix) swap
`intel-media-driver` / `iHD` for `intel-vaapi-driver` / `i965`.

If the disk is not `/dev/nvme0n1`: fix `device` in
[`hosts/work-laptop/disk.nix`](../../hosts/work-laptop/disk.nix).

If monitor output names differ from `DP-5` / `DP-6` / `HDMI-A-1`: update the
kanshi profiles in
[`hosts/work-laptop/default.nix`](../../hosts/work-laptop/default.nix) and the
position in the `host-assertions-work-laptop` `extraScript` in `flake.nix`.

---

## 1. Pre-migration backup checklist

This is a **wipe** — everything not in a backup or this repo is gone. Copy to
external storage and verify before formatting:

- [ ] **Browser:** Zen Browser profile (`~/.var/app/app.zen_browser.zen/`) or
      export bookmarks + log into sync on the new machine.
- [ ] **SSH:** `~/.ssh/` (private keys, `config`, `known_hosts`, any work-specific
      identity files e.g. `id_work_ed25519`).
- [ ] **Git signing key:** confirm whether commits are signed (GPG or SSH) and
      back up the signing key.
- [ ] **GPG / age:** `~/.gnupg/` and confirm the **sops master age key** is in
      the password manager (the single recovery root — see
      [secrets.md](secrets.md)).
- [ ] **API tokens:** Jira and GitLab tokens from `~/.config/` (jira.nvim,
      gitlab.nvim — these are machine-local per DECISIONS 035; note them for
      re-entry post-install).
- [ ] **Container registries:** `~/.docker/config.json` (auth tokens for any
      private registries used with podman).
- [ ] **Work project checkouts:** any local branches not pushed to a remote, any
      `vendor/` or generated files not in VCS. `git status` in each work repo.
- [ ] **Corporate certificates:** `/etc/pki/ca-trust/source/anchors/` — any
      work-issued or self-signed CAs needed for internal services.
- [ ] **WireGuard private key:** export the existing WireGuard private key from
      NetworkManager (`sudo cat /etc/NetworkManager/system-connections/wg0.nmconnection`
      or from the VPN admin portal). You will paste it into sops in §5.
- [ ] **Spotify / media:** nothing to back up; note the login.
- [ ] **Documents / media:** inventory `~/` and copy what matters to external
      storage.

Write the inventory into this runbook's PR description so it is auditable.

---

## 2. Boot the installer

1. Download the **NixOS minimal ISO** (x86_64, unstable/latest) and write to USB:
   `dd if=nixos-minimal-*.iso of=/dev/sdX bs=4M status=progress; sync`
2. Boot the USB (disable Secure Boot if needed).
3. Networking: `sudo systemctl start wpa_supplicant` then `wpa_cli`, or plug in
   ethernet. Confirm `ping -c1 cache.nixos.org`.

**Keep the old Silverblue SSD un-wiped** (do not `shred` or reformat it) until
the "Ready for Monday" gate in §6 passes. If the new install fails, swap the SSD
back.

---

## 3. Partition + format with disko (LUKS)

```sh
# Get the repo onto the installer.
nix-shell -p git --run 'git clone https://github.com/DanielMauderer/desktop-nix /tmp/cfg'

# CONFIRM the target device in disk.nix matches `lsblk` (nvme0n1 vs sda).
# This ERASES the disk. disko prompts to set the LUKS passphrase.
sudo nix --experimental-features "nix-command flakes" run \
  github:nix-community/disko/latest -- \
  --mode disko /tmp/cfg/hosts/work-laptop/disk.nix
```

Verify with `lsblk` and `mount | grep /mnt` after it finishes.

---

## 4. Generate hardware config + install

```sh
# Generate WITHOUT filesystems — disko owns those.
sudo nixos-generate-config --no-filesystems --root /mnt

# Copy into the host dir.
sudo mkdir -p /tmp/cfg/hosts/work-laptop/hardware
sudo cp /mnt/etc/nixos/hardware-configuration.nix \
        /tmp/cfg/hosts/work-laptop/hardware/hardware-configuration.nix
```

Uncomment the `./hardware/hardware-configuration.nix` import in
[`hosts/work-laptop/default.nix`](../../hosts/work-laptop/default.nix).
Reconcile its `boot.initrd.availableKernelModules` with `hardware.nix` (drop
duplicates — the generated probe wins). Commit to the working branch.

```sh
sudo nixos-install --flake /tmp/cfg#work-laptop --no-root-passwd
sudo nixos-enter --root /mnt -c 'passwd maudi'
reboot
```

On reboot: LUKS passphrase → greetd → Hyprland.

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

Replace `age1PLACEHOLDERworklaptopxxx…` in `.sops.yaml` with the output, then
re-encrypt all work-laptop secrets:

```sh
cd ~/desktop-nix
# Update master key placeholder too if not done yet (see docs/runbooks/secrets.md §1).
sops updatekeys secrets/work-laptop/wireguard.yaml  # once file exists
```

### 5b. WireGuard VPN

```sh
# Create the wireguard secret — paste the private key at the prompt.
sops edit secrets/work-laptop/wireguard.yaml
# Content:
#   wireguard-key: <paste private key here>
```

In `hosts/work-laptop/default.nix`, uncomment the `sops.secrets.wireguard-key`
and `networking.wg-quick.interfaces.wg0` blocks. Fill in the peer details
(endpoint, server public key, allowed IPs, assigned address, DNS). Then:

```sh
sudo nixos-rebuild switch --flake ~/desktop-nix#work-laptop
```

Test the tunnel:
```sh
sudo wg show          # interface + peer should appear
ping <work-internal-host>
curl https://internal.work.example.com
```

### 5c. First managed rebuild

```sh
sudo nixos-rebuild switch --flake ~/desktop-nix#work-laptop
```

**Theming bootstrap:** stylix derives the palette from
`modules/nixos/desktop/wallpaper.png` at build time — nothing to seed by hand.

---

## 6. Hardware + acceptance validation checklist

Run on the machine after first boot and VPN setup. The **"Ready for Monday"
gate** — marked with ⛔ — must pass before the old Silverblue SSD is wiped.

### Base & desktop (from pilot — re-verify)

- [ ] **Wi-Fi** connects (`nmtui`) and survives a reboot
- [ ] **Audio** out + mic (`pavucontrol` / `wpctl status`), volume keys
- [ ] **Bluetooth** pairs (waybar bluetooth → blueman)
- [ ] **Suspend/resume** (lid close + `systemctl suspend`) — display, wifi,
      audio all return
- [ ] **Brightness** keys (`XF86MonBrightness*` → brightnessctl) move the bar
- [ ] **Battery** waybar module shows charge + state; power-profile module toggles
- [ ] **Hyprland** starts from greetd; waybar renders all modules
- [ ] **Notifications** (swaync) appear; control centre opens
- [ ] **Screenshot** (hyprshot) and **lock** (swaylock) work; auto-lock fires
      after 5 minutes of idle
- [ ] **Wallpaper re-theme**: select a new wallpaper → GTK/Qt/kitty/waybar/rofi
      recolor
- [ ] **nvim** `:checkhealth` clean; LSP/treesitter load; Jira + GitLab tokens
      re-entered and integrations working
- [ ] **Media**: `mpv` plays 1080p/4K with hardware decode (`vainfo` shows iHD)
- [ ] **App launches**: Zen Browser, Spotify, imv
- [ ] **Containers**: `podman run hello-world` succeeds
- [ ] **VMs**: `virsh -c qemu:///system list` returns (libvirt active)

### Work-laptop-specific

- [ ] ⛔ **Dual-external dock** (`work-laptop-docked-dual`): plug in DP-5 + DP-6
      — internal display disables, both externals come up; workspaces pinned
      correctly
- [ ] ⛔ **Single HDMI dock** (`work-laptop-docked-hdmi`): plug in HDMI-A-1 —
      internal + external both active, correct positions; undocking falls back to
      `laptop-internal`
- [ ] ⛔ **WireGuard tunnel**: `sudo wg show` shows peer; work-internal host
      reachable; DNS resolves internal names
- [ ] ⛔ **Work repo clone + devshell**: clone a representative work repo, enter
      its devshell (`direnv allow`), run build + tests — **green before wiping**
- [ ] ⛔ **Dev environment**: `cargo`, `go`, `node`, `python`, `gh` all on PATH
      in their respective devshells; `docker` alias resolves to podman
- [ ] ⛔ **VMs**: a work-related VM boots in virt-manager (if applicable)
- [ ] **Firewall**: `nft list ruleset` shows the filter table; `ssh localhost`
      refused (daemon not running)
- [ ] **Rollback drill**: make a deliberately broken change, `switch`, reboot,
      pick prior generation from systemd-boot menu, confirm boot. Then roll back.

---

## 7. Rollback plan

- **Bad rebuild:** systemd-boot menu → prior generation, or
  `sudo nixos-rebuild switch --rollback`.
- **Install failure / emergency**: NixOS installer USB (re-run from §3). Keep it
  on the shelf. The old Silverblue SSD is also on the shelf until §6 gates pass.
- **SSD swap**: if needed before the old system is imaged, swap the SSD back and
  boot Silverblue normally — the NixOS SSD can be set aside and retried later.

---

## 8. Post-migration: backport lessons

After the machine is stable, file follow-ups against the relevant module tickets
for anything surfaced during migration (wrong output names in kanshi, missing
firmware, VAAPI driver mismatch, suspend quirks, corporate cert import, etc.).
Record decision changes in [DECISIONS.md](../DECISIONS.md). Ticket 15 (desktop)
should start from the corrected modules.

Specifically check:
- Do any corporate CAs need to be added to `security.pki.certificates` in
  `hosts/work-laptop/default.nix`?
- Did any work projects need containers/distrobox instead of a devshell?
- Was the WireGuard peer config correct, or does work have a second VPN?
