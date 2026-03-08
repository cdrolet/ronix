# Shared Hardware Profile: NVMe SSD
#
# Purpose: NVMe SSD support with disk device and TRIM optimization
# Usage: Add "nvme-ssd" to host's hardware list
# Feature: 045-shared-hardware-profiles
#
# Provides:
# - Disk device set to /dev/nvme0n1 (standard NVMe device)
# - Periodic TRIM (fstrim) for SSD longevity and performance
#
# Use this for physical machines with an NVMe SSD.
# Works alongside any storage profile (standard-partitions, luks-encrypted).
# For SATA SSDs, use "sata-ssd" instead.
{
  config,
  lib,
  pkgs,
  ...
}: {
  # NVMe SSD appears as /dev/nvme0n1
  _module.args.disks = lib.mkDefault ["/dev/nvme0n1"];

  # Weekly TRIM to maintain SSD performance and longevity
  services.fstrim = {
    enable = lib.mkDefault true;
    interval = lib.mkDefault "weekly";
  };
}
