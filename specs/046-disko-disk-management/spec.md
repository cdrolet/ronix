# Feature Specification: Disko Declarative Disk Management

**Feature Branch**: `046-disko-disk-management`\
**Created**: 2026-02-07\
**Status**: Draft\
**Input**: User description: "Migrate from manual partition scripts in install-remote.sh to disko for declarative disk management. Storage hardware profiles (standard-partitions.nix, luks-encrypted.nix) should become disko configurations that serve as single source of truth for both install-time partitioning and runtime fileSystems config. install-remote.sh should call disko instead of manual parted/mkfs/mount commands. This eliminates the sync problem between shell scripts and Nix partition declarations."

## Problem

Disk partition layout is currently defined in two disconnected places:

1. **Shell script** (`system/nixos/lib/init-disk.sh`) — creates partitions, formats, and mounts at install time
1. **Nix config** (`system/shared/hardware/storage/standard-partitions.nix`) — declares `fileSystems` entries at runtime

These must be kept manually in sync. If the shell script creates labels `NIXOS`/`BOOT`/`SWAP` but the Nix config references different labels, the system fails to boot. Adding a new partition layout (e.g., LUKS encryption) requires duplicating changes across both places.

There is no validation that the two stay aligned. The problem compounds with each new storage profile.

## User Scenarios & Testing

### User Story 1 - Single Source of Truth for Disk Layout (Priority: P1)

A system administrator defines a disk partition layout once. That single definition is used both to partition a fresh disk at install time and to generate the runtime filesystem mount configuration. No separate shell script is needed.

**Why this priority**: Eliminates the core sync problem. Without this, every storage profile requires maintaining parallel definitions.

**Independent Test**: Can be fully tested by creating a new host with a storage profile, running a fresh install, and verifying the system boots with correctly mounted filesystems — all from one configuration file.

**Acceptance Scenarios**:

1. **Given** a host declares a standard partition storage profile, **When** the system is installed on a fresh disk, **Then** partitions are created, formatted, labeled, and mounted according to the profile — without any separate shell script
1. **Given** a host declares a standard partition storage profile, **When** the system boots after installation, **Then** `fileSystems` entries match the partition layout exactly (same devices, labels, mount points, filesystem types)
1. **Given** the storage profile is modified (e.g., swap size changed), **When** a new install is performed, **Then** both install-time partitioning and runtime mounts reflect the change from the single definition

______________________________________________________________________

### User Story 2 - LUKS Encrypted Disk Layout (Priority: P1)

A system administrator selects a LUKS-encrypted storage profile for a physical host. The encrypted layout is defined in one place — the same profile handles LUKS container creation at install time and `initrd.luks` + `fileSystems` configuration at runtime.

**Why this priority**: LUKS is the primary motivation for this feature (upcoming physical host). Without single-source LUKS config, the encrypted partition setup is error-prone.

**Independent Test**: Can be tested by installing a host with the LUKS storage profile and verifying: LUKS containers are created at install, password prompt appears at boot, root and swap are decrypted and mounted correctly.

**Acceptance Scenarios**:

1. **Given** a host declares the LUKS-encrypted storage profile, **When** installed on a fresh disk, **Then** LUKS containers are created for root and swap, formatted, and mounted — from the single profile definition
1. **Given** a LUKS-encrypted host has been installed, **When** the system boots, **Then** it prompts for the LUKS passphrase and successfully decrypts and mounts root and swap
1. **Given** a LUKS-encrypted host has been installed, **When** checking the runtime NixOS configuration, **Then** `boot.initrd.luks.devices`, `fileSystems`, and `swapDevices` all match the profile definition

______________________________________________________________________

### User Story 3 - Install Script Integration (Priority: P2)

The installation script (`install-remote.sh`) uses the host's declared storage profile to partition and format disks automatically. The administrator does not need to pass a separate `init-disk` flag or know which shell script runs — the install process reads the host configuration and partitions accordingly.

**Why this priority**: Improves the install experience but depends on US1/US2 being complete first.

**Independent Test**: Can be tested by running `install-remote.sh` for a host and verifying disk partitioning happens automatically based on the host's storage profile without requiring a separate `init-disk` argument.

**Acceptance Scenarios**:

1. **Given** a host with a storage profile, **When** `install-remote.sh` is run for a fresh install, **Then** disk partitioning and formatting happen automatically based on the storage profile
1. **Given** a host with a storage profile and a disk that is already partitioned, **When** `install-remote.sh` is run, **Then** the user is warned and asked for confirmation before re-partitioning
1. **Given** a host without a storage profile defined, **When** `install-remote.sh` is run with `init-disk`, **Then** a clear error message explains that no storage profile is configured

______________________________________________________________________

### User Story 4 - Auto-Detect Disk Device (Priority: P2)

The storage profiles automatically detect the target disk device (VirtIO, SCSI, NVMe, etc.) without requiring the administrator to hardcode device paths. This supports both VM and physical host installations.

**Why this priority**: Required for portability across different hardware, but the detection logic is secondary to the core single-source-of-truth goal.

**Independent Test**: Can be tested by installing the same host configuration on different disk types (VirtIO vs NVMe) and verifying correct device detection without configuration changes.

**Acceptance Scenarios**:

1. **Given** a VM with a VirtIO disk (`/dev/vda`), **When** the storage profile partitions the disk, **Then** it correctly targets `/dev/vda`
1. **Given** a physical host with an NVMe disk (`/dev/nvme0n1`), **When** the storage profile partitions the disk, **Then** it correctly targets `/dev/nvme0n1`
1. **Given** a machine with multiple disks, **When** the storage profile runs, **Then** it targets the correct disk (first detected or explicitly configured in host config)

______________________________________________________________________

### Edge Cases

- What happens when the target disk already has partitions? The user must be warned and confirm before destructive operations.
- What happens when no disk device is found? A clear error message is shown listing expected device paths.
- What happens when a host declares both `standard-partitions` and `luks-encrypted`? A build-time error prevents conflicting storage profiles.
- What happens during install if LUKS passphrase entry fails? The install process exits with a clear error; no partial formatting occurs.
- What happens when disk size is too small for the partition layout? A clear error is shown with minimum disk size requirements.

## Requirements

### Functional Requirements

- **FR-001**: System MUST define partition layout, filesystem types, labels, and mount points in a single configuration file per storage profile
- **FR-002**: System MUST use the same configuration file for both install-time partitioning and runtime filesystem mounts
- **FR-003**: System MUST support standard (unencrypted) partition layouts: root (ext4), boot (vfat), and swap
- **FR-004**: System MUST support LUKS-encrypted partition layouts: encrypted root, encrypted swap, unencrypted boot
- **FR-005**: System MUST auto-detect disk device type (VirtIO, SCSI, NVMe) without hardcoded device paths
- **FR-006**: System MUST prevent conflicting storage profiles from being declared on the same host (build-time error)
- **FR-007**: The installation script MUST use the host's storage profile to partition disks instead of separate shell scripts
- **FR-008**: System MUST prompt for confirmation before destructive disk operations on pre-existing partitions
- **FR-009**: System MUST produce clear error messages when disk device is not found, disk is too small, or storage profile is missing
- **FR-010**: Storage profiles MUST use overridable defaults so hosts can customize specific values (e.g., swap size, filesystem type) without replacing the entire profile
- **FR-011**: The existing `init-disk.sh` shell script MUST be removed after migration to eliminate the duplicate definition

### Key Entities

- **Storage Profile**: A declarative definition of disk partition layout including partitions, filesystems, labels, mount points, and optional encryption. Used for both install-time creation and runtime mounting.
- **Host Configuration**: Declares which storage profile to use via the `hardware` field. A host references exactly zero or one storage profile.
- **Installation Script**: Orchestrates fresh NixOS installation including disk preparation, configuration application, and first boot setup.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Partition layout is defined in exactly one file per storage profile — no parallel shell script or duplicate Nix declarations exist
- **SC-002**: A fresh NixOS install using a storage profile boots successfully on first attempt with all filesystems correctly mounted
- **SC-003**: A fresh NixOS install with LUKS encryption prompts for passphrase at boot and decrypts/mounts all filesystems correctly
- **SC-004**: Changing a storage profile value (e.g., swap size) and reinstalling results in the updated layout on disk — no other files need modification
- **SC-005**: The same storage profile works across different disk types (VirtIO, NVMe) without host-specific changes
- **SC-006**: Build-time validation catches conflicting or missing storage profiles before installation begins

## Assumptions

- The host always has exactly one disk to partition (single-disk systems). Multi-disk/RAID setups are out of scope for this feature.
- Swap size defaults to 8GB (matching current `init-disk.sh` behavior). Hosts can override if needed.
- Boot partition size defaults to 512MB (matching current behavior).
- LUKS uses passphrase-based authentication (no TPM or keyfile for now).
- The NixOS ISO environment has all required tooling available for partitioning at install time.
- Darwin hosts do not use storage profiles (macOS manages its own disk layout).

## Out of Scope

- Multi-disk configurations (RAID, ZFS pools)
- Btrfs subvolume layouts
- TPM-based LUKS unlock
- Resizing partitions on existing installations
- Darwin (macOS) disk management
