# Quickstart: Disko Declarative Disk Management

**Feature**: 046-disko-disk-management

## For Host Creators

### Using Standard Partitions

Add `"standard-partitions"` to your host's hardware list:

```nix
# system/nixos/host/my-host/default.nix
{ ... }: {
  name = "my-host";
  architecture = "aarch64";
  family = ["linux" "gnome"];
  hardware = [
    "qemu-guest"
    "standard-partitions"  # Disko handles partitioning + fileSystems
    "desktop"
  ];
  applications = [];
  settings = ["default"];
}
```

No `hardware.nix` needed for filesystem declarations — disko generates them.

### Using LUKS Encryption

For physical hosts requiring disk encryption:

```nix
hardware = [
  "luks-encrypted"  # Instead of "standard-partitions"
  "desktop"
];
```

### Overriding Disk Device

By default, profiles target `/dev/vda` (VirtIO). For NVMe or other devices, the install script auto-detects, or you can override in your host config:

```nix
# In a host's hardware.nix (optional override)
{ ... }: {
  disko.devices.disk.main.device = "/dev/nvme0n1";
}
```

## For Installers

### Fresh NixOS Install

```bash
# Boot from NixOS ISO, then:
curl -L https://raw.githubusercontent.com/cdrolet/nix-config/main/install-remote.sh \
  -o install.sh && bash install.sh cdrokar avf-gnome init-disk
```

The install script:

1. Clones the repo
1. Auto-detects the disk device (VirtIO, SCSI, or NVMe)
1. Runs disko to partition/format/mount using the host's storage profile
1. Runs `nixos-install --flake .#user-host`

Pass `init-disk` to trigger disk initialization via disko.

### What Happens at Install Time

1. Script reads host config to find storage profile
1. Disko partitions, formats, and mounts to `/mnt`
1. `nixos-install --flake .#user-host` installs the system
1. On boot, NixOS uses the same disko config for `fileSystems`

## Verification

```bash
# After installation, verify mounts match disko config:
mount | grep -E '/(boot|mnt)?$'
lsblk -f

# For LUKS:
lsblk -f  # Should show crypto_LUKS type
ls /dev/mapper/  # Should show cryptroot, cryptswap
```

## Storage Profile Constraints

- Only ONE storage profile per host (`standard-partitions` OR `luks-encrypted`)
- Multiple storage profiles cause a build-time error
- Hosts without storage profiles skip disk initialization during install
