# Shared Hardware Profile: SPICE Guest Agent
#
# Purpose: SPICE VD agent for clipboard sharing and display auto-resize
# Usage: Add "spice" to host's hardware list
# Feature: 045-shared-hardware-profiles
#
# Provides:
# - SPICE VD agent (clipboard, display resize, drag-and-drop)
# - Only useful for QEMU VMs with SPICE display (not Apple Virtualization)
{
  config,
  lib,
  pkgs,
  ...
}: {
  # SPICE guest agent for clipboard sharing and better host integration
  services.spice-vdagentd.enable = lib.mkDefault true;
}
