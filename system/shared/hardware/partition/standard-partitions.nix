# Shared Hardware Profile: Standard Partitions (Disko)
#
# Purpose: Common unencrypted partition layout for NixOS (boot/root/swap)
# Usage: Add "standard-partitions" to host's hardware list
# Feature: 045-shared-hardware-profiles, 046-disko-disk-management
#
# Single source of truth — disko uses this for:
# - Install time: partitioning, formatting, and mounting via `disko --mode destroy,format,mount`
# - Runtime: auto-generates fileSystems, swapDevices NixOS config
#
# Partition layout:
#   ESP/Boot  512M  vfat  /boot
#   Root      remaining - 8G  ext4  /
#   Swap      8G
#
# Device override: set _module.args.disks = [ "/dev/nvme0n1" ] in host config
# Matches the layout previously created by init-disk.sh
{
  disks ? ["/dev/vda"],
  lib,
  ...
}: {
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = builtins.elemAt disks 0;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = lib.mkDefault ["umask=0077"];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
            swap = {
              size = "8G";
              content = {
                type = "swap";
              };
            };
          };
        };
      };
    };
  };
}
