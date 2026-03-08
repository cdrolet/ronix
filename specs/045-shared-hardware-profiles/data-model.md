# Data Model: Shared Hardware Profiles

**Feature**: 045-shared-hardware-profiles
**Date**: 2026-02-07

## Entities

### Hardware Profile

A reusable NixOS module file providing hardware configuration for a specific concern.

**Location**: `system/shared/hardware/{category}/{name}.nix`
**Reference format**: `"{category}/{name}"` (without `.nix` extension)

**Attributes**:

- Category (directory): Organizational grouping (e.g., `vm`, `graphics`, `storage`)
- Name (filename): Specific hardware concern (e.g., `qemu-guest`, `virtio-gpu`)
- Content: Standard NixOS module with `lib.mkDefault` for all settings

**Constraints**:

- One level of nesting only (`category/name`, not `category/sub/name`)
- Must use `lib.mkDefault` for all settings
- Must be \<200 lines
- Must include header documentation

### Host Hardware Field

A list of strings in the host's `default.nix` referencing shared hardware profiles.

**Schema location**: `system/shared/lib/host-schema.nix`
**Field**: `hardware`
**Type**: `lib.types.listOf lib.types.str`
**Default**: `[]`

**Examples**:

```nix
hardware = ["qemu-guest" "spice" "standard-partitions"];  # Bare names (fuzzy resolved)
hardware = ["vm/qemu-guest" "graphics/virtio-gpu"];        # Full paths (direct resolved)
hardware = ["qemu-guest" "vm/spice"];                      # Mixed (both work)
hardware = [];                                             # No shared profiles (default)
```

**Resolution rules**:

- Bare name (`"qemu-guest"`): searches all subdirectories recursively
- Full path (`"vm/qemu-guest"`): resolves directly to `system/shared/hardware/vm/qemu-guest.nix`
- Ambiguous bare name (matches multiple categories): build error listing all matches

### Local Hardware.nix

Existing per-host hardware configuration file.

**Location**: `system/nixos/host/{hostname}/hardware.nix`
**Priority**: Loaded LAST (overrides shared profiles)
**Optional**: Host can have shared profiles only, local only, both, or neither

## Loading Order

```
1. system/nixos/settings/system/hardware.nix     (universal: firmware, graphics)
2. system/shared/hardware/{profiles}...           (shared: from host.hardware field)
3. system/nixos/host/{hostname}/hardware.nix      (local: host-specific overrides)
```

## Relationships

```
Host default.nix
  |-- hardware: ["vm/qemu-guest", "vm/spice"]    # references shared profiles
  |-- family: ["linux", "gnome"]                   # orthogonal to hardware
  |-- local hardware.nix                           # overrides shared profiles

Shared hardware profile
  |-- self-contained NixOS module
  |-- no dependencies on other profiles
  |-- uses lib.mkDefault for all values
```
