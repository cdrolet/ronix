# Shared Hardware Profile: SATA SSD
#
# Purpose: SATA SSD support with disk device and TRIM optimization
# Usage: Add "sata-ssd" to host's hardware list
# Feature: 045-shared-hardware-profiles
#
# Provides:
# - Disk device set to /dev/sda (standard SATA device)
# - Periodic TRIM (fstrim) for SSD longevity and performance
#
# Use this for physical machines with a SATA SSD.
# Works alongside any storage profile (standard-partitions, luks-encrypted).
# For NVMe SSDs, use "nvme-ssd" instead.
{
  config,
  lib,
  pkgs,
  ...
}: {
  # SATA SSD appears as /dev/sda
  _module.args.disks = lib.mkDefault ["/dev/sda"];

  # Weekly TRIM to maintain SSD performance and longevity
  services.fstrim = {
    enable = lib.mkDefault true;
    interval = lib.mkDefault "weekly";
  };
}
