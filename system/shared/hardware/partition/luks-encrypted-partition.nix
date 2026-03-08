# Shared Hardware Profile: LUKS Encrypted Partition (Disko)
#
# Purpose: Full disk encryption for NixOS physical hosts
# Usage: Add "luks-encrypted-partition" to host's hardware list (instead of "standard-partitions")
# Feature: 045-shared-hardware-profiles, 046-disko-disk-management
#
# Single source of truth — disko uses this for:
# - Install time: LUKS container creation, formatting, and mounting
# - Runtime: auto-generates fileSystems, swapDevices, boot.initrd.luks.devices
#
# Partition layout:
#   ESP/Boot  512M  vfat       /boot (unencrypted, required for systemd-boot)
#   LUKS Root remaining - 8G   luks -> ext4  / (encrypted, mapper: cryptroot)
#   LUKS Swap 8G               luks -> swap    (encrypted, mapper: cryptswap)
#
# Single passphrase at boot: NixOS initrd automatically retries previously
# entered passphrases on subsequent LUKS volumes. Use the SAME passphrase
# for both cryptroot and cryptswap during disko format — you'll only be
# prompted once at boot.
#
# Device override: set _module.args.disks = [ "/dev/nvme0n1" ] in host config
# Mutually exclusive with "standard-partitions".
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
                type = "luks";
                name = "cryptroot";
                settings = {
                  allowDiscards = lib.mkDefault true;
                };
                content = {
                  type = "filesystem";
                  format = "ext4";
                  mountpoint = "/";
                };
              };
            };
            swap = {
              size = "8G";
              content = {
                type = "luks";
                name = "cryptswap";
                settings = {
                  allowDiscards = lib.mkDefault true;
                };
                content = {
                  type = "swap";
                };
              };
            };
          };
        };
      };
    };
  };
}
