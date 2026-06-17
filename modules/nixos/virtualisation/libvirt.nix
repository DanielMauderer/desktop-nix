# libvirt + qemu/KVM (Ticket 09) — the desktop virtualisation layer.
#
# Parity with maudiblue's stack (virt-manager, libvirt, qemu-kvm, virt-viewer
# and an enabled libvirtd.service), extended for Win11-class guests: an emulated
# TPM 2.0 (swtpm). UEFI/OVMF firmware no longer needs wiring — current nixpkgs
# ships every OVMF image QEMU distributes by default, so virt-manager's firmware
# dropdown already offers the Secure-Boot variant Windows 11 needs.
#
# maudiblue enabled libvirtd on every machine; on NixOS that becomes per-host,
# and DECISIONS 028 keeps all three. The module is therefore pulled in from
# modules/nixos/base (like dev/podman) rather than imported per host.
{ pkgs, ... }:
{
  virtualisation.libvirtd = {
    enable = true;

    # Don't auto-resume previously-running guests on boot, but shut any running
    # guest down cleanly when the host powers off (avoids dirty qcow2 images).
    onBoot = "ignore";
    onShutdown = "shutdown";

    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      # Emulated TPM 2.0 — Windows 11 refuses to install/boot without one.
      swtpm.enable = true;
    };
  };

  # virt-manager GUI (sets up its dbus + dconf wiring) and the lightweight
  # virt-viewer console client. Polkit auth under Hyprland goes through the
  # agent chosen in Ticket 04 (hyprpolkitagent); because maudi is in the
  # libvirtd group below, qemu:///system needs no password prompt at all.
  programs.virt-manager.enable = true;
  environment.systemPackages = [ pkgs.virt-viewer ];

  # The system socket is group-rw to `libvirtd`, so this is what lets maudi
  # reach qemu:///system without root (see modules/nixos/core/users.nix).
  users.users.maudi.extraGroups = [ "libvirtd" ];

  # NixOS's libvirtd module does not define libvirt's built-in "default" NAT
  # network, so a freshly-provisioned host has no guest networking until you
  # run `virsh net-define`. Define + autostart it declaratively via a oneshot
  # so `virsh net-list` shows it out of the box (DECISIONS 028).
  systemd.services.libvirt-default-network = {
    description = "Define and autostart the libvirt default NAT network";
    wantedBy = [ "multi-user.target" ];
    after = [ "libvirtd.service" ];
    requires = [ "libvirtd.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script =
      let
        netXml = pkgs.writeText "libvirt-default-net.xml" ''
          <network>
            <name>default</name>
            <forward mode='nat'/>
            <bridge name='virbr0' stp='on' delay='0'/>
            <ip address='192.168.122.1' netmask='255.255.255.0'>
              <dhcp>
                <range start='192.168.122.2' end='192.168.122.254'/>
              </dhcp>
            </ip>
          </network>
        '';
      in
      ''
        virsh="${pkgs.libvirt}/bin/virsh"
        if ! $virsh net-info default >/dev/null 2>&1; then
          $virsh net-define ${netXml}
        fi
        $virsh net-autostart default
        # Starting can fail in constrained sandboxes; defining + autostart is
        # what matters here, so don't fail the unit if the start doesn't take.
        $virsh net-start default 2>/dev/null || true
      '';
  };
}
