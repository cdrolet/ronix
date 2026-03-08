# Feature Specification: Shared Hardware Profiles

**Feature Branch**: `045-shared-hardware-profiles`\
**Created**: 2026-02-07\
**Status**: Draft\
**Input**: User description: "I would like a new hardware dir under shared where different hardware profile can be reused. it should support sub folder for classification such as graphic, vmware, utm, physical, container, etc. module stored here can be refered by the host with a new field 'hardware' that can take a list loading all hardware modules as part of the build. some might be generic for all apple virtualization by example while other module focus on harddisk or graphic. the host will still load the local hardware.nix located in its folder and should overwrite anything that come from the hardware field"

## Problem Statement

Currently, hardware configuration lives in two places:

1. **Shared settings** (`system/nixos/settings/system/hardware.nix`) - applies to all NixOS hosts (firmware, graphics)
1. **Per-host** (`system/nixos/host/{hostname}/hardware.nix`) - machine-specific (boot, filesystems, drivers, VM tools)

This causes **duplication** across VM hosts. Both `avf-gnome/hardware.nix` and `qemu-niri/hardware.nix` repeat similar QEMU guest configuration, boot loaders, filesystem layouts, and SPICE/virtio settings. When a new VM host is added, this boilerplate must be copied and adapted.

There is no way to share hardware configuration at a granular level. A host is either fully custom (copy everything into its `hardware.nix`) or gets only the universal defaults.

## Solution

Introduce a **shared hardware profiles directory** (`system/shared/hardware/`) containing reusable hardware modules organized by category. Hosts reference these profiles via a new `hardware` field in the host schema. The host's local `hardware.nix` is loaded last, giving it override priority.

______________________________________________________________________

## User Scenarios & Testing

### User Story 1 - Reuse Hardware Profiles Across Hosts (Priority: P1)

A system administrator creates a new NixOS VM host. Instead of copying boilerplate hardware configuration from an existing VM host, they reference shared hardware profiles in the host's `default.nix`. The shared profiles provide common VM settings (QEMU guest, SPICE, virtio, boot loader), and the host's local `hardware.nix` only contains machine-specific overrides (filesystem layout, unique drivers).

**Why this priority**: This is the core value of the feature - eliminating duplication and making new host creation faster and less error-prone.

**Independent Test**: Create a new host that references shared hardware profiles and verify it builds successfully with `nix flake check`. Confirm that shared profile settings are present in the built configuration and that host-specific overrides take precedence.

**Acceptance Scenarios**:

1. **Given** a shared hardware profile exists at `system/shared/hardware/vm/qemu-guest.nix`, **When** a host declares `hardware = ["qemu-guest"]`, **Then** the profile is found by name (regardless of subdirectory) and included in the host's NixOS build.
1. **Given** a host declares `hardware = ["vm/qemu-guest"]` with the full category path, **Then** the profile is resolved directly without searching.
1. **Given** a host references `hardware = ["qemu-guest"]` and also has a local `hardware.nix` that sets `boot.loader.systemd-boot.enable = true`, **Then** the local `hardware.nix` setting takes precedence over any conflicting value in the shared profile.
1. **Given** a host references multiple profiles `hardware = ["qemu-guest", "spice", "virtio-gpu"]`, **Then** all three profiles are loaded and their settings are combined in the build.

______________________________________________________________________

### User Story 2 - Organize Profiles by Category (Priority: P2)

A system administrator browses the shared hardware directory and can quickly find relevant profiles organized into categories (e.g., `vm/`, `graphics/`, `storage/`, `network/`). Each profile is a self-contained module focused on a single hardware concern.

**Why this priority**: Good organization makes the feature sustainable as the number of profiles grows. Without categories, the directory becomes a flat mess.

**Independent Test**: Verify that profiles in subdirectories are correctly resolved when referenced by hosts. A profile at `system/shared/hardware/vm/qemu-guest.nix` is referenced as `"vm/qemu-guest"` in the host's `hardware` list.

**Acceptance Scenarios**:

1. **Given** a profile exists at `system/shared/hardware/graphics/virtio-gpu.nix`, **When** a host declares `hardware = ["virtio-gpu"]`, **Then** the profile is found by searching subdirectories and loaded.
1. **Given** profiles exist in multiple categories (`vm/`, `graphics/`, `storage/`), **When** a host references profiles from different categories by name only, **Then** all referenced profiles are found and loaded regardless of category.
1. **Given** a profile named `common.nix` exists in both `vm/` and `graphics/`, **When** a host declares `hardware = ["common"]`, **Then** the build fails with an error listing both matches and instructing the user to use the full path (`"vm/common"` or `"graphics/common"`).

______________________________________________________________________

### User Story 3 - Host Local Hardware.nix Overrides Shared Profiles (Priority: P1)

A system administrator needs machine-specific hardware settings (unique filesystem layout, specific disk labels, custom kernel modules) that differ from the shared profiles. They put these in the host's local `hardware.nix`, which takes override priority over any shared profiles.

**Why this priority**: Override capability is essential - without it, shared profiles would be too rigid to be useful. Hosts must always be able to customize.

**Independent Test**: Create a shared profile that sets a value with `lib.mkDefault`, create a host that references it and also sets the same value in its local `hardware.nix`. Verify the local value wins.

**Acceptance Scenarios**:

1. **Given** a shared profile sets `services.qemuGuest.enable = lib.mkDefault true` and a host's local `hardware.nix` sets `services.qemuGuest.enable = false`, **Then** the host's local setting (`false`) is applied.
1. **Given** a host has a local `hardware.nix` but no `hardware` field in its `default.nix`, **Then** only the local `hardware.nix` is loaded (backward compatible).
1. **Given** a host has a `hardware` field but no local `hardware.nix`, **Then** only the shared profiles are loaded (local file is optional).

______________________________________________________________________

### Edge Cases

- What happens when a host references a profile that does not exist? Build fails with a clear error message identifying the missing profile and listing available profiles.
- What happens when a bare name matches profiles in multiple categories? Build fails with an ambiguity error listing all matches and instructing the user to use the full `category/name` path.
- What happens when a host has an empty `hardware` list (`hardware = []`)? No shared profiles are loaded; only the local `hardware.nix` (if it exists) is used. This is the default behavior.
- What happens when two shared profiles set conflicting values? Standard NixOS module merging applies. Both profiles should use `lib.mkDefault` so the host's local `hardware.nix` can override either.
- What happens when a host has neither a `hardware` field nor a local `hardware.nix`? The host builds with only the universal shared settings from `system/nixos/settings/system/hardware.nix`. This is backward compatible with existing behavior.
- What happens when a host uses a full path like `"vm/qemu-guest"`? It resolves directly without searching other subdirectories.

## Requirements

### Functional Requirements

- **FR-001**: System MUST support a shared hardware profiles directory at `system/shared/hardware/` containing reusable hardware configuration modules.
- **FR-002**: The shared hardware directory MUST support subdirectory categorization (e.g., `vm/`, `graphics/`, `storage/`, `network/`). Profile nesting depth is limited to one level (category/profile).
- **FR-003**: The host schema MUST include a new `hardware` field that accepts a list of strings referencing shared hardware profiles (e.g., `["qemu-guest", "spice", "virtio-gpu"]`).
- **FR-004**: The `hardware` field MUST default to an empty list, preserving backward compatibility for all existing hosts.
- **FR-005**: Referenced hardware profiles MUST be loaded as NixOS modules during the system build.
- **FR-006**: The host's local `hardware.nix` file MUST be loaded after shared hardware profiles, giving it override priority.
- **FR-007**: The system MUST fail with a clear error message when a host references a hardware profile that does not exist, listing available profiles.
- **FR-008**: Shared hardware profiles MUST use `lib.mkDefault` for all settings to allow host-level overrides.
- **FR-009**: The `hardware` field MUST only be used by NixOS hosts (system-level context). Darwin hosts do not have hardware modules.
- **FR-010**: The system MUST support fuzzy resolution: a bare name like `"qemu-guest"` MUST be resolved by searching all subdirectories under `system/shared/hardware/`. A full path like `"vm/qemu-guest"` MUST resolve directly.
- **FR-011**: When a bare name matches profiles in multiple subdirectories, the system MUST fail with an ambiguity error listing all matching paths and instructing the user to use the full `category/name` path.

### Key Entities

- **Hardware Profile**: A reusable NixOS module file located under `system/shared/hardware/{category}/{name}.nix`. Contains hardware-specific configuration (drivers, services, boot settings) for a particular hardware concern.
- **Host Hardware Field**: A list of strings in the host's `default.nix` that references shared hardware profiles. Entries can be bare names (`"qemu-guest"`) resolved by searching all subdirectories, or full paths (`"vm/qemu-guest"`) resolved directly. The `.nix` extension is omitted.
- **Local Hardware.nix**: The existing per-host hardware configuration file at `system/nixos/host/{hostname}/hardware.nix`. Loaded last for override priority.

## Success Criteria

### Measurable Outcomes

- **SC-001**: New VM hosts can be created by referencing shared profiles, reducing host-specific hardware configuration to only machine-unique settings (filesystem layout, disk labels).
- **SC-002**: All existing hosts continue to build without modification (full backward compatibility).
- **SC-003**: `nix flake check` passes after adding the shared hardware directory and updating at least one host to use the new `hardware` field.
- **SC-004**: A missing hardware profile reference produces a clear, actionable error message at build time.
- **SC-005**: An ambiguous bare name (matching multiple categories) produces a clear error listing all matches.

## Assumptions

- Hardware profiles are NixOS-only (system-level modules using `services.*`, `boot.*`, `hardware.*` options). Darwin does not need this feature.
- Profile naming follows the existing convention: lowercase with hyphens (e.g., `qemu-guest.nix`, `virtio-gpu.nix`).
- Profiles are independent modules - each profile can be used alone without requiring other profiles (no inter-profile dependencies).
- The loading order is: universal shared settings -> shared hardware profiles (in list order) -> local hardware.nix.
- Subdirectory depth is one level (e.g., `vm/qemu-guest.nix` is valid, `vm/apple/utm.nix` is not).

## Scope

### In Scope

- New `system/shared/hardware/` directory with category subdirectories
- New `hardware` field in host schema
- Loading mechanism in NixOS library
- Validation for missing profiles
- Migration of at least one existing VM host to use shared profiles as proof of concept

### Out of Scope

- Refactoring `system/nixos/settings/system/hardware.nix` (universal settings stay as-is)
- Darwin hardware support
- Auto-discovery of hardware profiles (hosts must explicitly reference them)
- Hardware detection at runtime (this is declarative configuration only)
