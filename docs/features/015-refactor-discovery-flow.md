# Feature 015: Discovery Flow Refactoring

**Status**: Implemented\
**Branch**: `015-refactor-discovery-flow-clean`

## What Changed

This feature introduced two major improvements to the nix-config build system:

1. **Renamed /system to /platform**: Standardized terminology throughout the codebase for better clarity
1. **3-Parameter Build Interface**: Changed from concatenated strings to explicit parameters

## How to Use

### Building Configurations

**New 3-parameter format**:

```bash
just build <user> <platform> <profile>
just install <user> <platform> <profile>
just diff <user> <platform> <profile>
```

**Examples**:

```bash
# Build configurations
just build cdrokar darwin home-macmini-m4
just build cdrolet darwin work

# Install configurations
just install cdrokar darwin home-macmini-m4

# Show differences
just diff cdrokar darwin work
```

### Validation and Error Messages

The interface provides clear validation at each level:

```bash
# Invalid user
$ just build invalid-user darwin work
Error: Invalid user 'invalid-user'
Valid users: cdrokar cdrolet cdronix

# Invalid platform
$ just build cdrokar windows work
Error: Invalid platform 'windows'
Valid platforms: darwin nixos

# Invalid profile for platform
$ just build cdrokar darwin invalid-profile
Error: Invalid profile 'invalid-profile' for platform 'darwin'
Valid profiles for darwin: home-macmini-m4 work
```

### Listing Available Options

```bash
# List all users
just list-users

# List profiles organized by platform
just list-profiles
# Output:
# Available profiles by platform:
# ===============================
# 
# darwin:
#   - home-macmini-m4
#   - work
# 
# nixos:

# List all valid combinations
just list-combinations
```

## Directory Structure

The `platform/` directory contains platform-specific configurations:

```
platform/
├── darwin/                # macOS-specific
│   ├── app/               # Darwin apps
│   ├── settings/          # System settings
│   ├── lib/               # Platform libraries
│   └── profiles/          # Deployment profiles
├── nixos/                 # Linux-specific
└── shared/                # Cross-platform
```

**User imports**:

```nix
discovery = import ../../platform/shared/lib/discovery.nix { inherit lib; };
```

## Benefits

1. **Clearer Build Commands**: Separate parameters make it obvious what you're building
1. **Better Error Messages**: Each parameter is validated independently with helpful suggestions
1. **Organized Output**: List commands show profiles grouped by platform
1. **Consistent Terminology**: "platform" accurately describes darwin/nixos/etc distinction
1. **Clean Git History**: Directory rename preserved full file history (100% similarity)

## Migration Guide

### Update Build Commands

```bash
# Old format (no longer supported)
just build cdrokar darwin-home-macmini-m4

# New format  
just build cdrokar darwin home-macmini-m4
```

### Update Import Paths

All Nix imports referencing `system/` need to change to `platform/`:

```nix
# Old
discovery = import ../../system/shared/lib/discovery.nix { inherit lib; };

# New
discovery = import ../../platform/shared/lib/discovery.nix { inherit lib; };
```

### Flake Outputs

The flake no longer exports `validProfilesPrefixed`. For validation, use the justfile commands:

```bash
just list-profiles          # Show available profiles
just list-combinations      # Show all valid combinations
```

## Validation Commands

All justfile commands now validate inputs and provide clear error messages:

```bash
# Check available options
just list-users             # See all valid users
just list-profiles          # See profiles by platform
just list-combinations      # See all valid combinations

# Validate before building
just build <user> <platform> <profile>
```
