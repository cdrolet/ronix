# Contract: hostSpec Configuration Structure

**Feature**: 013-refactor-system-structure\
**Created**: 2025-01-27\
**Version**: 1.0.0

## Purpose

Defines the standard contract for host identification configuration that eliminates platform-specific boilerplate in profile files.

## Structure

```nix
hostSpec = {
  name: string;        # Required: Hostname identifier
  display: string;     # Required: Human-readable display name
  platform: string;    # Required: Target platform architecture
};
```

## Field Specifications

### name (string, required)

**Purpose**: Hostname identifier that will be set as `networking.hostName`

**Format**:

- Valid hostname format (alphanumeric characters + hyphens)
- No spaces or special characters
- Must be unique within a deployment context

**Examples**:

- `"home-macmini"`
- `"work-laptop"`
- `"server-1"`

**Validation**:

- Must be non-empty string
- Build fails immediately if missing
- Type validated via Nix module system (`lib.types.str`)

### display (string, required)

**Purpose**: Human-readable display name that will be set as `networking.computerName`

**Format**:

- Any non-empty string
- Can contain spaces and special characters
- Used for system identification in UI

**Examples**:

- `"Home Mac Mini"`
- `"Work Laptop"`
- `"Production Server"`

**Validation**:

- Must be non-empty string
- Build fails immediately if missing
- Type validated via Nix module system (`lib.types.str`)

### platform (string, required)

**Purpose**: Target platform architecture that will be set as `nixpkgs.hostPlatform`

**Format**:

- Valid Nix system identifier
- Must match NixOS/nix-darwin platform requirements

**Examples**:

- `"aarch64-darwin"` (Apple Silicon macOS)
- `"x86_64-darwin"` (Intel macOS)
- `"x86_64-linux"` (Linux x86_64)
- `"aarch64-linux"` (Linux ARM64)

**Validation**:

- Must be non-empty string
- Build fails immediately if missing
- Type validated via Nix module system (`lib.types.str`)
- Actual platform validation performed by nix-darwin/NixOS during build

## Module Integration

### Usage in Profile

```nix
{ config, pkgs, lib, ... }:

{
  imports = [
    # System settings (uses auto-discovery)
    ../../settings/default.nix
  ];

  # Host identification (standardized)
  hostSpec = {
    name = "home-macmini";
    display = "Home Mac Mini";
    platform = "aarch64-darwin";
  };

  # Profile-specific overrides
  system.defaults.dock.autohide = lib.mkForce true;
}
```

### Processing Module

The `system/shared/lib/host.nix` module processes hostSpec and sets:

- `networking.hostName = hostSpec.name`
- `networking.computerName = hostSpec.display`
- `nixpkgs.hostPlatform = hostSpec.platform`

### Generated Configuration

After processing, the profile automatically has:

```nix
{
  networking.hostName = "home-macmini";
  networking.computerName = "Home Mac Mini";
  nixpkgs.hostPlatform = "aarch64-darwin";
}
```

## Error Handling

### Missing Required Fields

**Error Type**: Build failure (strict validation)

**Error Message**: Must clearly indicate which fields are missing

**Example**:

```
error: The option 'hostSpec.name' is used but not defined.
error: The option 'hostSpec.display' is used but not defined.
```

### Invalid Field Types

**Error Type**: Type validation error

**Error Message**: Nix module system provides type error messages

**Example**:

```
error: The option value 'hostSpec.name' in '/path/to/profile/default.nix' is not of type 'string'.
```

## Versioning

**Version**: 1.0.0\
**Stability**: Stable (part of feature implementation)\
**Future Extensions**: Structure is extensible for additional fields (e.g., location, environment tags)

## Cross-Platform Compatibility

This contract is designed to be cross-platform:

- ✅ Works for Darwin (nix-darwin)
- ✅ Ready for NixOS (future implementation)
- ✅ Platform field determines actual platform-specific behavior

## Compliance

**Implementation**: `system/shared/lib/host.nix`\
**Usage**: All profile `default.nix` files\
**Testing**: Profile builds validate contract automatically via Nix module system
