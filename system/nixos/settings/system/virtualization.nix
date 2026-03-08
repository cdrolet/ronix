# NixOS: VM Integration Services (System-Level)
#
# Purpose: Configure VM guest tools for Linux VMs (QEMU, SPICE)
# Platform: NixOS (uses services.* and systemd options)
# Context: System-level (runs before home-manager)
#
# This module enables VM integration services that improve the experience
# when running Linux as a guest in virtualization platforms:
# - QEMU Guest Agent: Time sync, snapshots, shutdown coordination
# - SPICE VD Agent: Clipboard sharing, display resolution, mouse integration
#
# Why NixOS Settings (not family):
# - QEMU/SPICE are VM guest tools, not desktop-specific
# - Uses NixOS-only module options (services.*, systemd.*)
# - Work with any Linux desktop (GNOME, KDE, Niri, etc.)
# - systemd-based conditional activation (Linux-specific)
#
# Runtime Detection:
# Services are installed on all systems but only run when virtualization
# is detected at runtime (via systemd ConditionVirtualization). This allows
# the same config to work on both bare metal and VMs without build-time logic.
#
# Constitutional: <200 lines, uses lib.mkDefault for user-overridability
#
# User-level counterpart: system/shared/family/linux/settings/user/virtualization.nix
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
  # Note: On UTM with Apple Virtualization, qemu-guest-agent may not work
  # due to missing virtio-serial channel. Enable anyway for compatibility
  # with standard QEMU/KVM platforms.
  #
  # Service installed but only runs on VMs (see systemd condition below)
  services.qemuGuest.enable = lib.mkDefault true;

  # ============================================================================
  # SPICE VD Agent
  # ============================================================================
  # SPICE (Simple Protocol for Independent Computing Environments) guest tools
  # Provides seamless desktop integration when running in SPICE-enabled VMs:
  # - Clipboard sharing (copy/paste between host and guest)
  # - Dynamic display resolution (auto-resize on window change)
  # - Mouse pointer integration (no capture/release needed)
  # - Multi-monitor support
  #
  # Architecture:
  # - System daemon (spice-vdagentd): Runs as root, handles virtio-serial
  # - User agent (spice-vdagent): Runs in user session, handles clipboard
  #
  # This module enables the system daemon. User agent is installed via
  # the linux family user-level virtualization.nix counterpart.
  #
  # Compatibility:
  # - Works on both x86_64 and aarch64 (Apple Silicon)
  # - UTM uses SPICE for clipboard (both QEMU and Apple Virtualization)
  # - Standard QEMU/KVM platforms
  #
  # Service installed but only runs on VMs (see systemd condition below)
  services.spice-vdagentd.enable = lib.mkDefault true;

  # ============================================================================
  # Systemd Runtime Conditions
  # ============================================================================
  # Prevent VM services from starting on bare metal hardware
  # ConditionVirtualization=vm ensures services only run when hypervisor detected
  #
  # This approach allows:
  # - Same config deployed to bare metal and VMs
  # - No build-time detection logic needed
  # - Services installed but dormant on bare metal (zero overhead)
  # - Automatic activation when booted in VM
  #
  # Detected hypervisors: kvm, qemu, vmware, virtualbox, xen, hyperv, etc.
  # See: systemd.unit(5) ConditionVirtualization

  systemd.services.qemu-guest-agent = lib.mkIf config.services.qemuGuest.enable {
    unitConfig.ConditionVirtualization = "vm";
  };

  systemd.services.spice-vdagentd = lib.mkIf config.services.spice-vdagentd.enable {
    unitConfig.ConditionVirtualization = "vm";
  };

  # VM-specific settings
  virtualisation.vmware.guest.enable = lib.mkDefault false;
}
