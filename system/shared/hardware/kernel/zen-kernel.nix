# Shared Hardware Profile: Zen Kernel
#
# Purpose: Performance-oriented kernel for desktop/gaming workloads
# Usage: Add "zen-kernel" to host's hardware list
# Feature: 045-shared-hardware-profiles
#
# Provides:
# - linux-zen kernel (latency-tuned, BFQ scheduler, optimised for desktop responsiveness)
# - Fully cached via cache.nixos.org — no additional substituters required
#
# Suitable for: any x86_64 physical host (AMD or Intel)
# Not useful for VMs — the host kernel already handles scheduling there
# Pair with ondemand-power or performance-power for best results
{pkgs, lib, ...}: {
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_zen;
}
