# Shared Hardware Profile: Performance CPU Governor
#
# Purpose: Maximum CPU performance at all times
# Usage: Add "performance" to host's hardware list
# Feature: 045-shared-hardware-profiles
#
# Behavior: Always runs CPU at maximum frequency.
# Use for workstations, build servers, or latency-sensitive machines.
{
  config,
  lib,
  pkgs,
  ...
}: {
  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";
}
