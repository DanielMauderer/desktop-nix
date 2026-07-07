{ pkgs, ... }:
{
  virtualisation.libvirtd = {
    enable = true;

    # Don't auto-resume guests on boot, but shut running guests down cleanly on
    # host poweroff (avoids dirty qcow2 images).
    onBoot = "ignore";
    onShutdown = "shutdown";

    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      # Emulated TPM 2.0 — Windows 11 refuses to install/boot without one.
      swtpm.enable = true;
    };
  };

  programs.virt-manager.enable = true;
  environment.systemPackages = [ pkgs.virt-viewer ];

  # Group-rw socket lets maudi reach qemu:///system without root.
  users.users.maudi.extraGroups = [ "libvirtd" ];

  # NixOS's libvirtd module doesn't define the built-in "default" NAT network,
  # so define + autostart it declaratively (otherwise guests have no networking
  # until a manual `virsh net-define`).
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
        # Starting can fail in constrained sandboxes; define + autostart is what
        # matters, so don't fail the unit if start doesn't take.
        $virsh net-start default 2>/dev/null || true
      '';
  };
}
