# home-server

Headless services host — the only non-desktop machine. Install guide:
[INSTALL.md](INSTALL.md).

- **Role:** headless home server (containers + storage + VPN + the git forge +
  the document archive + push notifications + the shared database + the
  observability stack)
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
  an **ntfy push-notification server** (`ntfy.mauderer.work` via the proxy, so
  notifications reach the phone off-LAN; closed by default — deny-all, no
  self-signup, services publish with a token), a shared **PostgreSQL** server
  for future services (socket-only — no TCP listener at all — peer auth, cluster
  on the SSD, nightly `pg_dumpall` to the pool), an **observability stack**
  (Prometheus with node/smartctl/postgres/blackbox exporters; Loki fed by
  Grafana Alloy from both the journal and NPM's nginx log files; Grafana itself
  VPN-only on `10.100.0.1:3030` with datasources, four dashboards and the alert
  rules all provisioned from Nix; alerts delivered to the ntfy server above, so
  a full disk or a stopped backup reaches the phone. Loki's `:3100` is open to
  the podman bridge, LAN and VPN so deployments can push), and the container
  groundwork for docker-compose / Ansible-managed services. WAN surface is
  exactly UDP 51820 + TCP 80/443.
- **Disk:** disko SSD root; ZFS data pool on the HBA drives.

`hardware.nix` carries the ZFS `hostId`, the LTS kernel, HBA modules and zram.
SSH is **key-only** — enroll the admin public key in
`users.users.maudi.openssh.authorizedKeys.keys` in `default.nix` before install,
or you'll lock yourself out (there's no console/GUI).
