# Data Model: Host/Family Architecture

**Feature**: 021-host-family-refactor\
**Phase**: Phase 1 - Design & Contracts\
**Date**: 2025-12-02

## Overview

This document defines the data entities, relationships, validation rules, and structure for the host/family architecture refactoring. Families are cross-platform shared configurations (e.g., "linux" family shared by nixos/kali, "gnome" desktop family).

## Entity Definitions

### Entity 1: Host Configuration

**Description**: Pure data configuration representing a physical or virtual machine's identity and configuration requirements.

**Location**: `platform/{platform}/host/{name}/default.nix`

**Structure**:

```nix
{ ... }:

{
  name = "string";              # Required: Host identifier
  family = ["string"];          # Optional: Array of cross-platform family names
  applications = ["string"];    # Array of app names, or ["*"] for all
  settings = ["string"];        # Array of setting names, or ["default"] for all platform settings
}
```

**Fields**:

| Field | Type | Required | Description | Validation |
|-------|------|----------|-------------|------------|
| `name` | String | Yes | Host identifier (e.g., "home-macmini-m4") | Non-empty string |
| `family` | Array<String> | No | References to cross-platform family names | Each family must exist in `platform/shared/family/{name}/` |
| `applications` | Array<String> | No | List of application names to install | Valid app names or \["*"\] |
| `settings` | Array<String> | No | List of settings to apply | Valid setting names, ["default"], but NOT \["*"\] |

**Validation Rules**:

1. `name` MUST be non-empty string
1. Each family name in `family` array MUST reference existing directory in `platform/shared/family/`
1. `family` array MAY be empty `[]` to explicitly disable family resolution
1. `applications` array MAY use wildcard "\*" to import all discovered apps
1. `settings` array MUST NOT use wildcard "\*" (throws error)
1. `settings` array MAY use "default" to import all platform-specific settings
1. No imports allowed (pure data only)

**Example (Linux platform with families)**:

```nix
{ ... }:

{
  name = "nixos-workstation";
  family = ["linux", "gnome"];  # Compose linux + gnome families
  applications = [
    "git"
    "helix"
    "zsh"
  ];
  settings = [
    "default"  # Import all nixos settings
  ];
}
```

**Example (Darwin platform without families)**:

```nix
{ ... }:

{
  name = "home-macmini-m4";
  family = [];  # Darwin typically doesn't share cross-platform
  applications = ["*"];  # All apps
  settings = ["default"];
}
```

**Relationships**:

- References → `Family` (via `family` array)
- Discovered by → `Platform Library` (darwin.nix, nixos.nix)
- Contains → `Application` references (via `applications` array)
- Contains → `Setting` references (via `settings` array)

______________________________________________________________________

### Entity 2: Family (Cross-Platform Shared Configuration)

**Description**: Cross-platform reusable configuration bundle that can be referenced by multiple hosts across different platforms. Provides common applications and settings for platform families (linux, gnome, server) that span platform boundaries. NOT for deployment contexts (work, home, gaming) - hosts are specific enough for that.

**Location**: `platform/shared/family/{name}/`

**Structure**:

```text
platform/shared/family/{name}/
├── app/
│   ├── default.nix         # Optional: Auto-installed when family referenced
│   ├── {appname}.nix       # Individual apps
│   └── {category}/
│       └── {appname}.nix
└── settings/
    ├── default.nix         # Optional: Auto-installed when family referenced
    └── {setting}.nix       # Individual settings
```

**Components**:

| Component | Type | Required | Description |
|-----------|------|----------|-------------|
| `app/` directory | Directory | No | Contains family-specific applications |
| `app/default.nix` | File | No | Auto-imported applications (if exists) |
| `settings/` directory | Directory | No | Contains family-specific settings |
| `settings/default.nix` | File | No | Auto-imported settings (if exists) |

**Validation Rules**:

1. Family name MUST be valid directory name (no special chars except dash/underscore)
1. `app/default.nix` if present MUST be valid Nix module
1. `settings/default.nix` if present MUST be valid Nix module
1. Individual app/setting files MUST be \<200 lines (constitutional requirement)
1. Families MUST be cross-platform reusable (not platform-specific contexts)

**Example Structure (Linux family)**:

```text
platform/shared/family/linux/
├── app/
│   ├── default.nix         # Common Linux tools
│   ├── htop.nix
│   └── tmux.nix
└── settings/
    ├── default.nix         # Common Linux settings
    └── systemd.nix
```

**Example Structure (GNOME desktop family)**:

```text
platform/shared/family/gnome/
├── app/
│   ├── default.nix         # GNOME apps
│   ├── nautilus.nix
│   └── gnome-terminal.nix
└── settings/
    ├── default.nix         # GNOME settings
    └── gtk-theme.nix
```

**Relationships**:

- Referenced by → `Host` (via host.family array)
- Contains → `Application` modules (in app/ directory)
- Contains → `Setting` modules (in settings/ directory)
- Discovered by → `Hierarchical Discovery System`
- Used by → Multiple platforms (nixos, kali, ubuntu for "linux" family)

______________________________________________________________________

### Entity 3: Application

**Description**: Installable program configured via Nix modules. Can exist in multiple tiers of the hierarchy.

**Location**:

- **Tier 1** (platform-specific): `platform/{platform}/app/{category}/{name}.nix`
- **Tier 2** (family-specific): `platform/shared/family/{family}/app/{name}.nix`
- **Tier 3** (shared): `platform/shared/app/{category}/{name}.nix`

**Search Order**: Platform → Families (in array order) → Shared (first match wins)

**Structure** (unchanged from Feature 020):

```nix
{ config, pkgs, lib, ... }:

{
  home.packages = [ pkgs.appname ];
  
  programs.appname = {
    enable = true;
    # ... configuration
  };
  
  # Optional: Shell aliases
  home.shellAliases = {
    "alias-name" = "command";
  };
}
```

**Validation Rules**:

1. Module MUST be \<200 lines
1. MUST have header documentation
1. MUST use `lib.mkDefault` for overridable options
1. App name in discovery MUST match filename (e.g., "git" → git.nix)

**Relationships**:

- Referenced by → `Host.applications` array
- Imported by → `Platform Library` (via hierarchical discovery)
- May exist in → Platform, Family, or Shared tier

______________________________________________________________________

### Entity 4: Setting

**Description**: System configuration module (dock, displays, keyboard, etc.). Can exist in multiple tiers of the hierarchy.

**Location**:

- **Tier 1** (platform-specific): `platform/{platform}/settings/{name}.nix`
- **Tier 2** (family-specific): `platform/shared/family/{family}/settings/{name}.nix`
- **Tier 3** (shared): `platform/shared/settings/{name}.nix`

**Search Order**: Platform → Families (in array order) → Shared (first match wins)

**Special Keyword**: "default"

- When `settings = ["default"]` in host config
- Imports ALL settings from `platform/{platform}/settings/` (tier 1 only)
- Matches existing darwin/settings/default.nix pattern

**Structure**:

```nix
{ config, pkgs, lib, ... }:

{
  # Platform-specific settings
  # e.g., for darwin:
  system.defaults.dock = {
    autohide = true;
    # ...
  };
}
```

**Validation Rules**:

1. Module MUST be \<200 lines
1. MUST have header documentation
1. MUST use `lib.mkDefault` for overridable options
1. Wildcard "\*" is FORBIDDEN (validation error)
1. "default" keyword only searches tier 1 (platform-specific)

**Relationships**:

- Referenced by → `Host.settings` array
- Imported by → `Platform Library` (via hierarchical discovery)
- May exist in → Platform, Family, or Shared tier

______________________________________________________________________

## Entity Relationships Diagram

```text
┌─────────────────┐
│   Host Config   │  (Pure Data)
│  platform/      │
│   {platform}/   │
│    host/{name}/ │
└────────┬────────┘
         │
         │ references (optional array)
         ├──────────────────────┐
         │                      │
         ▼                      ▼
┌────────────────┐    ┌─────────────────┐
│  Family 1,2..  │    │  Platform Lib   │
│  platform/     │    │  darwin.nix     │
│   shared/      │◄───┤  nixos.nix      │
│    family/     │    └────────┬────────┘
│     {name}/    │             │
└────────────────┘             │
         │                     │ loads & generates imports
         │                     │
         ├─────────────────────┼─────────────────────┐
         │                     │                     │
         ▼                     ▼                     ▼
┌─────────────────┐   ┌──────────────┐    ┌─────────────────┐
│  Applications   │   │   Settings   │    │  Discovery      │
│                 │   │              │    │  System         │
│  Tier 1: platform│   │ Tier 1: platform│   │                 │
│  Tier 2: families│   │ Tier 2: families│   │  Hierarchical   │
│  Tier 3: shared  │   │ Tier 3: shared  │   │  Search         │
└─────────────────┘   └──────────────┘    └─────────────────┘
```

**Flow**:

1. Platform lib loads host config as pure data (before module eval)
1. Extracts host.family (array), host.applications, host.settings
1. If family array non-empty: auto-install each family's defaults (app/default.nix, settings/default.nix)
1. For each app: hierarchical discovery (platform → family1 → family2 → ... → shared)
1. For each setting: hierarchical discovery (platform → family1 → family2 → ... → shared)
1. Special: "default" setting imports all from platform tier only
1. Generate combined imports list
1. Pass to home-manager module system

______________________________________________________________________

## State Transitions

### Host Configuration State

**States**:

- **Unloaded**: File exists but not yet imported
- **Loaded**: Imported as attribute set (pre-module evaluation)
- **Validated**: Passed validation checks (profile exists, no "\*" in settings, etc.)
- **Resolved**: Applications and settings discovered via hierarchy
- **Built**: Nix derivation built successfully

**Transitions**:

```text
Unloaded → Loaded (platform lib imports file)
Loaded → Validated (validation checks pass)
Validated → Resolved (hierarchical discovery completes)
Resolved → Built (Nix builds derivation)
```

**Error States**:

- **Invalid Profile**: Referenced profile doesn't exist
- **Invalid App/Setting**: Name not found in any tier
- **Wildcard Error**: Settings array contains "\*"
- **Build Error**: Nix build fails

______________________________________________________________________

## Validation Rules Summary

### Host Configuration Validation

| Rule | Severity | Message Template |
|------|----------|------------------|
| Name non-empty | ERROR | "Host name cannot be empty" |
| Family exists | ERROR | "Family '{family}' not found in platform/shared/family/" |
| No imports | ERROR | "Host config must be pure data (no imports allowed)" |
| Settings no wildcard | ERROR | "Settings cannot use '\*' wildcard. Use 'default' or list specific settings." |
| Valid app names | WARNING | "Application '{app}' not found in any tier: platform, families, shared" |
| Valid setting names | WARNING | "Setting '{setting}' not found in any tier: platform, families, shared" |

### Family Validation

| Rule | Severity | Message Template |
|------|----------|------------------|
| Valid directory name | ERROR | "Family name '{name}' contains invalid characters" |
| Defaults are valid modules | ERROR | "Family '{family}' app/default.nix is invalid: {error}" |
| Cross-platform purpose | WARNING | "Family '{name}' should be for cross-platform sharing (linux, gnome, server), not deployment contexts (work, home)" |
| Module size \<200 lines | ERROR | "Family module '{file}' exceeds 200 lines ({count} lines)" |

### Application/Setting Validation

| Rule | Severity | Message Template |
|------|----------|------------------|
| Module size \<200 lines | ERROR | "Module '{name}' exceeds 200 lines ({count} lines)" |
| Has header docs | WARNING | "Module '{name}' missing header documentation" |
| Uses lib.mkDefault | WARNING | "Module '{name}' should use lib.mkDefault for overridable options" |

______________________________________________________________________

## Data Flow

### Host Loading Flow

```text
1. Platform lib (darwin.nix) starts
   ↓
2. Import host file: hostData = import ../host/{name} { };
   ↓
3. Extract fields:
   - hostName = hostData.name
   - hostFamily = hostData.family or []
   - hostApps = hostData.applications or []
   - hostSettings = hostData.settings or []
   ↓
4. Validate:
   - Check each family in array exists
   - Check settings don't contain "*"
   ↓
5. Auto-install family defaults (for each family in array):
   - Check platform/shared/family/{family1}/app/default.nix
   - Check platform/shared/family/{family1}/settings/default.nix
   - Check platform/shared/family/{family2}/app/default.nix
   - Check platform/shared/family/{family2}/settings/default.nix
   - ... (for all families)
   ↓
6. Resolve applications via hierarchy:
   - For each app in hostApps:
     - Search platform/{platform}/app/
     - Search platform/shared/family/{family1}/app/
     - Search platform/shared/family/{family2}/app/
     - ... (for all families in order)
     - Search platform/shared/app/
     - Return first match
   ↓
7. Resolve settings via hierarchy:
   - Handle "default" keyword specially (import all platform settings)
   - For other settings:
     - Search platform/{platform}/settings/
     - Search platform/shared/family/{family1}/settings/
     - Search platform/shared/family/{family2}/settings/
     - ... (for all families in order)
     - Search platform/shared/settings/
     - Return first match
   ↓
8. Generate imports list:
   - hostData (pure data)
   - family defaults (if exist, for all families)
   - resolved apps
   - resolved settings
   - home-manager bootstrap
   ↓
9. Pass to home-manager.users.{user}.imports
   ↓
10. Module system evaluates and builds
```

______________________________________________________________________

## Migration from Old to New

### Old Profile Structure

```nix
# platform/darwin/profiles/work/default.nix
{ config, pkgs, lib, ... }:

{
  imports = [
    ../../../shared/lib/host.nix
    ../../settings/default.nix
  ];
  
  host = {
    name = "work-laptop";
    display = "Work Laptop";
    platform = "aarch64-darwin";
  };
}
```

### New Host Structure (Darwin - no families)

```nix
# platform/darwin/host/work/default.nix
{ ... }:

{
  name = "work-laptop";
  family = [];  # Darwin typically doesn't share cross-platform
  applications = ["*"];  # Explicit (was in user config)
  settings = ["default"];  # Replaces import ../../settings/default.nix
}
```

### New Host Structure (Linux - with families)

```nix
# platform/nixos/host/workstation/default.nix
{ ... }:

{
  name = "nixos-workstation";
  family = ["linux", "gnome"];  # Compose cross-platform families
  applications = ["*"];
  settings = ["default"];
}
```

**Key Changes**:

1. No imports (pure data)
1. Simplified to essential fields
1. `settings = ["default"]` replaces import of settings/default.nix
1. `family` field is array for composing cross-platform configurations
1. `applications` now explicit (previously implicit via user config)
1. Families are for cross-platform sharing (linux, gnome), not deployment contexts (work, home)

______________________________________________________________________

## Summary

This data model provides:

- **Clear entity boundaries**: Host, Family, Application, Setting
- **Hierarchical search**: Platform → Families (in array order) → Shared with first-match semantics
- **Pure data pattern**: Hosts are simple attribute sets (no imports)
- **Cross-platform sharing**: Families enable configuration reuse across platforms (nixos, kali, ubuntu)
- **Composability**: Multiple families can be composed via array (e.g., `["linux", "gnome"]`)
- **Validation rules**: Comprehensive checks for common errors
- **State transitions**: Well-defined flow from file to built system
- **Migration path**: Clear transformation from old to new structure

All entities follow constitutional requirements (\<200 lines, documented, declarative).
