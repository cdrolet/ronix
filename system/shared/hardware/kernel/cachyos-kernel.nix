# Shared Hardware Profile: CachyOS Kernel
#
# Purpose: AMD-optimised kernel with BORE scheduler, LTO, and PGO
# Usage: Add "cachyos-kernel" to host's hardware list
# Feature: 045-shared-hardware-profiles
#
# Provides:
# - linux-cachyos kernel (BORE scheduler, Clang LTO, PGO, AMD micro-arch tuning)
# - Binary cache via attic.xuyh0120.win/lantian and cache.garnix.io
#
# Suitable for: x86_64 physical hosts, especially AMD Ryzen systems
# Requires: nix-cachyos-kernel flake input declared in flake.nix
# Not useful for VMs — host kernel handles scheduling there
#
# Pair with amd-cpu for full AMD platform support
# NOTE: nixpkgs.follows is intentionally absent on this flake input —
#       version pinning is required for the binary cache to be a hit
{
  inputs,
  pkgs,
  lib,
  ...
}: {
  # Apply CachyOS overlay — exposes pkgs.cachyosKernels.*
  nixpkgs.overlays = [inputs.nix-cachyos-kernel.overlays.pinned];

  # Use latest CachyOS kernel (BORE + LTO + PGO)
  boot.kernelPackages = lib.mkDefault (
    pkgs.linuxKernel.packagesFor pkgs.cachyosKernels.linux_cachyos
  );

  # CachyOS binary caches — avoids local compilation (~2h build without cache)
  nix.settings = {
    substituters = [
      "https://attic.xuyh0120.win/lantian"
      "https://cache.garnix.io"
    ];
    trusted-public-keys = [
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];
  };
}
