# Shared Hardware Profile: SPICE Guest Agent
#
# Purpose: SPICE VD agent for clipboard sharing and display auto-resize
# Usage: Add "spice" to host's hardware list
# Feature: 045-shared-hardware-profiles
#
# Provides:
# - SPICE VD agent (clipboard, display resize, drag-and-drop)
# - Works with QEMU+SPICE and UTM (UTM uses SPICE for clipboard even with Apple Virtualization backend)
{
  config,
  lib,
  pkgs,
  ...
}: {
  # SPICE guest agent for clipboard sharing and better host integration
  # UTM uses SPICE protocol for clipboard/input even with Apple Virtualization backend
  services.spice-vdagentd.enable = lib.mkDefault true;
}
