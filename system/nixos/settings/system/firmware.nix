# Hardware Support
#
# Purpose: Enable firmware support for NixOS systems
# System-level configuration (NixOS)
#
# This module enables firmware support for:
# - WiFi and Bluetooth adapters
# - Audio devices
# - Network cards
# - Other hardware requiring proprietary/redistributable firmware
#
# Note: Graphics acceleration (hardware.graphics.enable) is handled by
# shared hardware profiles: "desktop" or "virtio-gpu" (Feature 045)
#
# Platform: NixOS only
# Context: System-level
#
# Constitutional: <200 lines, uses lib.mkDefault for user-overridability
#
# Usage:
# Automatically imported via NixOS settings auto-discovery
# Matches NixOS ISO behavior for broad hardware compatibility
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Enable ALL firmware packages (including non-redistributable/proprietary)
  # This includes firmware for:
  # - Broadcom WiFi and Bluetooth
  # - MacBook FaceTime HD camera
  # - Xbox wireless adapter
  # - And all redistributable firmware
  # Requires nixpkgs.config.allowUnfree = true (set in system.nix)
  hardware.enableAllFirmware = lib.mkDefault true;
}
