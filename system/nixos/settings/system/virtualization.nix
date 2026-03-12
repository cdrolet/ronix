# NixOS: VM Integration Services (System-Level)
#
# Purpose: Configure VM guest tools for Linux VMs (QEMU, SPICE)
# Platform: NixOS (uses services.* and systemd options)
# Context: System-level (runs before home-manager)
#
# Services enabled here are guarded at build-time via hardware profiles:
# - qemu-guest: enables qemu-guest-agent (with ConditionVirtualization=vm guard)
# - spice:      enables spice-vdagentd (no runtime guard — Apple Virtualization
#               is not detected as VM by systemd-detect-virt on aarch64)
#
# User-level counterpart: system/shared/family/wayland/settings/user/virtualization.nix
{
  config,
  lib,
  pkgs,
  ...
}: {
  # ============================================================================
  # QEMU Guest Agent
  # ============================================================================
  # Enables communication between VM host and guest for:
  # - Time synchronization
  # - VM snapshots (quiesce filesystem)
  # - Graceful shutdown/reboot coordination
  # - File system freeze/thaw for backups
  #
  # QEMU Guest Agent: time sync, snapshots, graceful shutdown
  # Only runs when QEMU/KVM hypervisor is detected at runtime.
  services.qemuGuest.enable = lib.mkDefault true;

  systemd.services.qemu-guest-agent = lib.mkIf config.services.qemuGuest.enable {
    unitConfig.ConditionVirtualization = "vm";
  };

  # SPICE VD Agent: clipboard sharing, display resize, mouse integration
  # No ConditionVirtualization guard — Apple Virtualization Framework (UTM/aarch64)
  # is not detected as a VM by systemd-detect-virt, so the service would never
  # start. The spice.nix hardware profile is the build-time guard instead.
  services.spice-vdagentd.enable = lib.mkDefault true;

  # VM-specific settings
  virtualisation.vmware.guest.enable = lib.mkDefault false;
}
