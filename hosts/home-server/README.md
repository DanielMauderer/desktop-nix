# home-server

Headless services host — the only non-desktop machine. Install guide:
[INSTALL.md](INSTALL.md).

- **Role:** headless home server (containers + storage + VPN + the git forge +
  the document archive + the shared database)
- **Kernel:** LTS (not CachyOS)
- **Modules:** `core` (the machine-agnostic baseline — boot, nix, networking,
  users, secrets, updates, hardening) + `dev` (Podman) + `server`. No `base`, so
  no GUI, audio, libvirt or fonts. The `cli` + `neovim` home modules give `maudi`
  the same shell as every other host.
- **`server` provides:** WireGuard **VPN server**, **VPN-only SSH**, a public
  **reverse proxy** (Nginx Proxy Manager on WAN 80/443; admin UI VPN-only on
  `10.100.0.1:81`; Let's Encrypt via HTTP-01), a **ZFS** data pool, an **NFS**
  export, a self-hosted **Forgejo** forge (`git.mauderer.work` via the proxy;
  git-SSH on 2222, LAN/VPN only) with an opt-in **Actions runner** that executes
  jobs as podman containers, a **Paperless-ngx document archive** (VPN-only on
  `10.100.0.1:28981`, never proxied; data on the pool, inbox on the NFS share),
  a shared **PostgreSQL** server for future services (socket-only — no TCP
  listener at all — peer auth, cluster on the SSD, nightly `pg_dumpall` to the
  pool), and the container groundwork for docker-compose / Ansible-managed
  services. WAN surface is exactly UDP 51820 + TCP 80/443.
- **Disk:** disko SSD root; ZFS data pool on the HBA drives.

`hardware.nix` carries the ZFS `hostId`, the LTS kernel, HBA modules and zram.
SSH is **key-only** — enroll the admin public key in
`users.users.maudi.openssh.authorizedKeys.keys` in `default.nix` before install,
or you'll lock yourself out (there's no console/GUI).
