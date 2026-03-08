# Shared Hardware Profile: Powersave CPU Governor
#
# Purpose: Minimize power consumption
# Usage: Add "powersave" to host's hardware list
# Feature: 045-shared-hardware-profiles
#
# Behavior: Always runs CPU at minimum frequency.
# Use for laptops on battery or low-power servers.
{
  config,
  lib,
  pkgs,
  ...
}: {
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
}
