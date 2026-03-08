# Shared Hardware Profile: AMD CPU
#
# Purpose: AMD processor support (microcode updates, CPU frequency scaling)
# Usage: Add "amd" to host's hardware list
# Feature: 045-shared-hardware-profiles
#
# Provides:
# - AMD CPU microcode updates (security and stability fixes)
# - amd_pstate driver for CPU frequency scaling
# - KVM virtualization support (AMD-V)
#
# Use this for any host with an AMD processor (Ryzen, EPYC, Athlon).
# Pair with "amd-gpu" for systems with AMD integrated/discrete graphics.
{
  config,
  lib,
  pkgs,
  ...
}: {
  # AMD CPU microcode updates
  # Critical for security patches (Zenbleed, Inception, etc.)
  hardware.cpu.amd.updateMicrocode = lib.mkDefault true;

  # amd_pstate driver for CPU frequency scaling
  boot.initrd.kernelModules = ["amd_pstate"];

  # AMD KVM support for virtualization
  boot.kernelModules = ["kvm-amd"];
}
