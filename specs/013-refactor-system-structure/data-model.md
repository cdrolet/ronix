# Data Model: Refactor System Structure

**Feature**: 013-refactor-system-structure\
**Created**: 2025-01-27\
**Purpose**: Define the logical entities, attributes, relationships, and validation rules for the system structure refactoring

______________________________________________________________________

## Overview

This data model describes the configuration entities that make up the refactored system structure. The refactoring introduces standardization through hostSpec, centralization of stateVersion, and automated discovery mechanisms.

______________________________________________________________________

## Core Entities

### 1. hostSpec

**Description**: Configuration structure containing host identification information that standardizes profile configuration across platforms.

**Attributes**:

- **name** (string, required): Hostname identifier matching networking.hostName requirement
  - Example: "home-macmini"
  - Validation: Must be valid hostname (alphanumeric + hyphen, no spaces)
- **display** (string, required): Human-readable display name matching networking.computerName requirement
  - Example: "Home Mac Mini"
  - Validation: Any non-empty string
- **platform** (string, required): Target platform architecture matching nixpkgs.hostPlatform requirement
  - Example: "aarch64-darwin", "x86_64-linux"
  - Validation: Must be valid Nix system identifier

**Relationships**:

- Used by: Profile modules (`system/{platform}/profiles/{profile}/default.nix`)
- Processed by: `system/shared/lib/host.nix` module
- Generates: `networking.hostName`, `networking.computerName`, `nixpkgs.hostPlatform`

**Validation Rules**:

- All three fields are REQUIRED (validation fails build if missing)
- Error messages must clearly indicate which fields are missing
- Type validation via Nix module system (`lib.types.str`)

**Location**: Defined in profile default.nix files, processed by `system/shared/lib/host.nix`

**Example**:

```nix
hostSpec = {
  name = "home-macmini";
  display = "Home Mac Mini";
  platform = "aarch64-darwin";
};
```

______________________________________________________________________

### 2. Discovery Functions Library

**Description**: Shared utilities for automatically finding and loading modules from directory structures.

**Functions**:

- **discoverUsers** (basePath: Path → [String]): Finds user directories with default.nix

  - Input: Base path to user directory (e.g., `./user`)
  - Output: List of user names (e.g., `["cdrokar", "cdrolet", "cdrixus"]`)
  - Logic: Filter directories that contain `default.nix` file

- **discoverProfiles** (platform: String → [String]): Finds profile directories for a platform

  - Input: Platform name (e.g., "darwin", "nixos")
  - Output: List of profile names (e.g., `["home-macmini-m4", "work"]`)
  - Logic: Filter directories in `system/${platform}/profiles/` with `default.nix`

- **discoverAllProfilesPrefixed** (→ [String]): Finds all profiles across platforms with prefixes

  - Input: None (uses existing platforms)
  - Output: List of prefixed profiles (e.g., `["darwin-home-macmini-m4", "darwin-work", "nixos-desktop"]`)
  - Logic: Map each platform's profiles to prefixed format

- **discoverModules** (basePath: Path → [String]): Recursively discovers all `.nix` files in a directory tree

  - Input: Base path to directory (e.g., `./system/darwin/settings`)
  - Output: List of relative file paths (e.g., `["dock.nix", "finder.nix", "dev/git.nix"]`)
  - Logic: Recursive traversal, exclude `default.nix`, filter `.nix` extension

**Relationships**:

- Used by: `flake.nix`, `system/darwin/settings/default.nix`, any defaults.nix file
- Located in: `system/shared/lib/discovery.nix`

**Validation Rules**:

- Functions must handle non-existent directories gracefully (Nix evaluation error is acceptable)
- `discoverModules` must exclude `default.nix` to prevent circular dependencies
- All functions must be pure (no side effects)

**State Management**:

- Pure functions: No state, only inputs/outputs
- Evaluation-time discovery: Functions execute during Nix evaluation
- Caching: Nix automatically caches evaluation results

______________________________________________________________________

### 3. System State Version Configuration

**Description**: Centralized Darwin system state version that applies to all profiles unless overridden.

**Attributes**:

- **value** (integer): State version number (e.g., 5)
- **location** (path): `system/darwin/lib/darwin.nix`
- **scope** (enum): Darwin-specific (not shared with NixOS)

**Relationships**:

- Set in: `system/darwin/lib/darwin.nix` (central default)
- Can be overridden in: Profile modules (profile overrides central)
- Applies to: All Darwin profiles by default

**Validation Rules**:

- Must be set in darwin.nix module list (lowest priority)
- Profiles can override using module system precedence
- No validation needed (nix-darwin validates stateVersion format)

**Override Precedence**:

1. Profile-level setting (highest priority)
1. Central default in darwin.nix (lowest priority)

**Location**: `system/darwin/lib/darwin.nix`

______________________________________________________________________

### 4. Auto-Discovery Configuration

**Description**: Configuration pattern for automatically importing modules without manual import statements.

**Pattern**:

- **Discovery Source**: Directory containing modules (e.g., `system/darwin/settings/`)
- **Discovery Function**: `discoverModules` from `system/shared/lib/discovery.nix`
- **Import Generation**: `map (file: ./${file}) (discoverModules ./.)`
- **Exclusions**: `default.nix` (to prevent circular dependencies)

**Relationships**:

- Used in: All `defaults.nix` files at app and settings level
- Imports: All `.nix` files discovered recursively in directory tree
- Generates: `imports` attribute list for Nix module

**Validation Rules**:

- Invalid Nix modules cause normal evaluation errors (no special handling)
- Empty directories result in empty imports list (valid, just no modules)
- Recursive discovery includes subdirectories (e.g., `dev/git.nix`)

**Location**: Applied in `system/darwin/settings/default.nix`, future app defaults.nix files

**Example**:

```nix
imports = map (file: ./${file}) (
  lib.callPackage ../../shared/lib/discovery.nix {}).discoverModules ./.
);
```

______________________________________________________________________

## State Transitions

### Profile Refactoring

**Before**:

```
Profile → Manual config (networking.hostName, networking.computerName, nixpkgs.hostPlatform)
```

**After**:

```
Profile → hostSpec → host.nix → Auto-generated config (networking.hostName, networking.computerName, nixpkgs.hostPlatform)
```

### Discovery Migration

**Before**:

```
flake.nix → Embedded discovery functions
```

**After**:

```
flake.nix → Import from system/shared/lib/discovery.nix
system/darwin/settings/default.nix → Use discovery.discoverModules
```

### State Version Centralization

**Before**:

```
Each profile → system.stateVersion = 5 (duplicated)
```

**After**:

```
darwin/lib/darwin.nix → system.stateVersion = 5 (central default)
Profile → Can override if needed (optional)
```

______________________________________________________________________

## Validation Rules Summary

### hostSpec Validation

- ✅ All three fields required (name, display, platform)
- ✅ Build fails immediately with clear error if missing
- ✅ Type validation via Nix module system

### Discovery Function Validation

- ✅ Pure functions (no side effects)
- ✅ Graceful handling of non-existent directories (Nix error acceptable)
- ✅ Circular dependency prevention (exclude defaults.nix)

### State Version Validation

- ✅ Set centrally in darwin.nix
- ✅ Profiles can override (module precedence)
- ✅ No format validation needed (nix-darwin handles)

### Auto-Discovery Validation

- ✅ Invalid modules cause normal Nix evaluation errors
- ✅ Recursive discovery includes subdirectories
- ✅ Excludes defaults.nix to prevent circular dependencies

______________________________________________________________________

## Constraints and Assumptions

### Constraints

- Must maintain backward compatibility (existing profiles work after refactoring)
- Must preserve flake.nix output structure (tooling compatibility)
- Must follow Constitution v2.0.4 principles

### Assumptions

- hostSpec structure name may be refined during implementation
- All existing Darwin profiles will be refactored to use hostSpec
- Future NixOS profiles will use similar hostSpec pattern (cross-platform ready)
- Darwin library function review will identify at least one redundant function or unnecessary module

______________________________________________________________________

## Data Flow Examples

### Profile Creation Flow

1. Developer creates `system/darwin/profiles/new-profile/default.nix`
1. Defines `hostSpec = { name = "..."; display = "..."; platform = "..."; }`
1. Imports `../../settings/default.nix` (which uses auto-discovery)
1. `host.nix` processes hostSpec → sets networking.\* and nixpkgs.hostPlatform
1. Profile builds with standardized configuration

### Settings Addition Flow

1. Developer creates `system/darwin/settings/bluetooth.nix`
1. `system/darwin/settings/default.nix` uses `discoverModules`
1. bluetooth.nix automatically discovered and imported
1. No manual import statement update needed
1. Settings immediately available to all profiles

### Discovery Function Usage Flow

1. `flake.nix` imports `system/shared/lib/discovery.nix`
1. Calls `discoverUsers ./user` → gets list of users
1. Calls `discoverProfiles "darwin"` → gets list of profiles
1. Generates user-profile combinations
1. Creates darwinConfigurations outputs
