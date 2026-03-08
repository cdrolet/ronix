# Contract: Disko Storage Profile Format
#
# All storage profiles in system/shared/hardware/storage/ MUST follow this structure.
# This is the contract for how disko configs are parameterized and composed.
#
# Feature: 046-disko-disk-management

# Standard partitions example (contract reference):
{disks ? ["/dev/vda"], ...}: {
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = builtins.elemAt disks 0;
        content = {
          type = "gpt";
          partitions = {
            # EFI System Partition (required for systemd-boot)
            ESP = {
              size = "512M"; # lib.mkDefault equivalent: overridable via _module.args
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            # Root filesystem
            root = {
              size = "100%"; # Remaining space after other partitions
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
            # Swap (sized from end of disk)
            # Note: disko orders partitions as declared
          };
        };
      };
    };
  };
}

# LUKS encrypted example (contract reference):
# Same structure but root partition uses:
#   content.type = "luks"
#   content.name = "cryptroot"
#   content.content = { type = "filesystem"; format = "ext4"; mountpoint = "/"; }
