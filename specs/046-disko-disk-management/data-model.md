# Data Model: Disko Declarative Disk Management

**Feature**: 046-disko-disk-management
**Date**: 2026-02-07

## Entities

### Storage Profile (disko config)

A declarative definition of disk layout using disko's `disko.devices` format.

**Attributes**:

- `disko.devices.disk.<name>.type` — always `"disk"`
- `disko.devices.disk.<name>.device` — target device path (parameterized)
- `disko.devices.disk.<name>.content.type` — partition table type (`"gpt"`)
- `disko.devices.disk.<name>.content.partitions` — partition definitions

**Partition attributes**:

- `size` — partition size (`"512M"`, `"8G"`, `"100%"`)
- `type` — GPT type code (`"EF00"` for EFI, omit for Linux)
- `content.type` — content type (`"filesystem"`, `"luks"`, `"swap"`)
- `content.format` — filesystem format (`"vfat"`, `"ext4"`)
- `content.mountpoint` — mount path (`"/boot"`, `"/"`)

**Location**: `system/shared/hardware/storage/<profile-name>.nix`

### Standard Partitions Profile

| Partition | Size | Type | Filesystem | Mount | Label |
|-----------|------|------|------------|-------|-------|
| ESP/Boot | 512M | EF00 | vfat | /boot | BOOT |
| Root | remaining - 8G | Linux | ext4 | / | NIXOS |
| Swap | 8G | Linux | swap | (swap) | SWAP |

### LUKS Encrypted Profile

| Partition | Size | Type | Content | Mount | Label |
|-----------|------|------|---------|-------|-------|
| ESP/Boot | 512M | EF00 | vfat | /boot | BOOT |
| LUKS Root | remaining - 8G | Linux | luks → ext4 | / | (mapper: cryptroot) |
| LUKS Swap | 8G | Linux | luks → swap | (swap) | (mapper: cryptswap) |

### Host Configuration

Hosts reference storage profiles via the existing `hardware` field.

**Constraint**: At most one storage profile from `storage/` category per host. Multiple storage profiles produce a build-time error.

**Example**:

```nix
{
  hardware = [
    "qemu-guest"
    "standard-partitions"  # or "luks-encrypted"
    "desktop"
  ];
}
```

### Disk Device Resolution

Storage profiles accept a default device that can be overridden.

**Priority order**:

1. Host-specific `_module.args.disks` override
1. `install-remote.sh` auto-detection (VirtIO → SCSI → NVMe)
1. Profile default (`/dev/vda`)

## Relationships

```
Host default.nix
  └── hardware = ["standard-partitions", ...]
        └── resolveHardwareProfiles
              └── system/shared/hardware/storage/standard-partitions.nix
                    └── disko.devices declaration
                          ├── Install time: disko partitions/formats/mounts
                          └── Runtime: auto-generates fileSystems, swapDevices, initrd.luks
```

## Validation Rules

1. **Single storage profile**: At most one `storage/*` profile per host
1. **Device exists**: Disko fails clearly if target device doesn't exist
1. **Partition sizes**: Must fit within disk capacity (disko validates at partition time)
1. **No manual fileSystems**: Hosts using disko must not manually declare `fileSystems` for disko-managed partitions
