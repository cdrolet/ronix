# Shared Hardware Profile: Apple Virtualization Framework
#
# Purpose: Apple Virtualization backend features (Rosetta, virtiofs)
# Usage: Add "apple-virtualization" to host's hardware list
# Feature: 045-shared-hardware-profiles
#
# Provides:
# - Rosetta for Linux (x86_64 binary translation on ARM64)
# - Virtiofs mount for Rosetta runtime
# - Virtiofs shared directory from host macOS (/mnt/share)
#
# Requires: UTM with Apple Virtualization backend (not QEMU backend)
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Rosetta for Linux - run x86_64 binaries on ARM64
  # Requires UTM with Apple Virtualization framework (not QEMU backend)
  virtualisation.rosetta = {
    enable = true;
    mountTag = "rosetta";
  };

  # Mount Rosetta runtime from host
  fileSystems."/run/rosetta" = {
    device = "rosetta";
    fsType = "virtiofs";
    options = ["ro"];
  };

  # Virtiofs shared directory from host macOS
  # UTM: VM Settings → Sharing → Enable Directory Sharing, mount tag "share"
  fileSystems."/mnt/share" = {
    device = "share";
    fsType = "virtiofs";
    options = ["defaults" "nofail"];
  };
}
