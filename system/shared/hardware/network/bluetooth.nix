# Shared Hardware Profile: Bluetooth
#
# Purpose: Enable Bluetooth support for physical machines
# Usage: Add "bluetooth" to host's hardware list
# Feature: 045-shared-hardware-profiles
#
# Provides:
# - Bluetooth hardware support
# - Bluetooth powered on at boot
#
# Use this for any physical machine with Bluetooth hardware.
# Firmware is handled separately by firmware.nix (hardware.enableAllFirmware).
{
  config,
  lib,
  pkgs,
  ...
}: {
  hardware.bluetooth = {
    enable = lib.mkDefault true;
    powerOnBoot = lib.mkDefault true;
  };
}
