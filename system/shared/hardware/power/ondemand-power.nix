# Shared Hardware Profile: Ondemand CPU Governor
#
# Purpose: Balance performance and power consumption
# Usage: Add "ondemand" to host's hardware list
# Feature: 045-shared-hardware-profiles
#
# Behavior: Runs CPU at low speed, ramps up quickly under load.
# Good default for mini PCs, desktops, and always-on machines.
{
  config,
  lib,
  pkgs,
  ...
}: {
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";
}
