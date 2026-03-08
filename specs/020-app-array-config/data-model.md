# Data Model: Simplified Application Configuration

**Feature**: 020-app-array-config\
**Date**: 2025-11-30\
**Status**: Complete

## Overview

This feature extends the user configuration data model with an optional `applications` field. The data model is purely declarative (Nix attribute sets and lists) with no persistent storage.

## Entity: User Configuration

**Location**: `user/{username}/default.nix`\
**Type**: Nix attribute set (Home Manager module)\
**Lifecycle**: Evaluated at build time, no runtime persistence

### Schema

```nix
{
  # Required fields (existing)
  user.name        :: String              # User's login name
  user.email       :: String              # User's email address
  user.fullName    :: String              # User's full display name
  
  # Optional locale fields (existing, Feature 018)
  user.languages   :: [String] | null     # Preferred languages
  user.keyboardLayout :: [String] | null  # Keyboard layouts
  user.timezone    :: String | null       # IANA timezone
  user.locale      :: String | null       # POSIX locale
  
  # New optional field (this feature)
  user.applications :: [String] | null    # Application names to import
}
```

### Field Specifications

#### `user.applications`

**Type**: `nullOr (listOf str)`\
**Default**: `null`\
**Required**: No (optional field)

**Description**: List of application names to automatically discover and import from the platform application registry.

**Validation Rules**:

1. **Type validation**: Must be null or list of strings (enforced by Nix type system)
1. **Name validation**: Each string validated by discovery system at evaluation time
1. **Platform availability**: Discovery system handles platform-specific apps gracefully
1. **Empty list**: Valid (results in no application imports)

**Valid Values**:

- `null` - No automatic application imports (default, backward compatible)
- `[]` - Empty list, no imports
- `[ "git" ]` - Single application
- `[ "git" "zsh" "helix" "aerospace" ]` - Multiple applications

**Invalid Values** (caught by Nix type system):

- `"git"` - Not a list (type error)
- `[ 1 2 3 ]` - Non-string list elements (type error)
- `[ "git" null "zsh" ]` - Mixed types in list (type error)

**Error Handling**:

- **Type errors**: Caught during Nix evaluation with standard type mismatch error
- **Unknown apps**: Caught by discovery system with helpful suggestions
- **Platform unavailable**: Discovery system gracefully skips (user configs only)

**Examples**:

```nix
# Valid: null (default)
user = {
  name = "cdrolet";
  applications = null;  # Explicit null (same as omitting field)
};

# Valid: empty list
user = {
  name = "cdrolet";
  applications = [];  # No imports, but field present
};

# Valid: single application
user = {
  name = "cdrolet";
  applications = [ "git" ];
};

# Valid: multiple applications
user = {
  name = "cdrolet";
  applications = [ "git" "zsh" "helix" "aerospace" ];
};

# Invalid: not a list (type error)
user = {
  name = "cdrolet";
  applications = "git";  # ERROR: expected list, got string
};

# Invalid: non-string elements (type error)
user = {
  name = "cdrolet";
  applications = [ "git" 42 ];  # ERROR: list element 1 has wrong type
};
```

______________________________________________________________________

## Entity: Application Registry

**Location**: Built dynamically by discovery system from `platform/*/app/` directories\
**Type**: Attribute set mapping application names to file paths\
**Lifecycle**: Built during Nix evaluation, cached per evaluation

### Schema

```nix
{
  platforms  :: [String]           # List of available platforms
  apps       :: AttrSet            # Applications per platform
  apps.shared :: [String]          # Cross-platform apps
  apps.{platform} :: [String]      # Platform-specific apps
  index      :: AttrSet            # App name → platforms mapping
  index.{appName} :: [String]      # Platforms where app exists
}
```

**Note**: This entity is managed entirely by the discovery system. No changes required for this feature.

______________________________________________________________________

## Entity: Discovery Module Output

**Type**: Nix module (attribute set with `imports` field)\
**Lifecycle**: Generated at evaluation time, consumed by Home Manager

### Schema

```nix
{
  imports :: [Path]  # List of absolute paths to application modules
}
```

**Example**:

```nix
{
  imports = [
    /nix/store/.../platform/shared/app/dev/git.nix
    /nix/store/.../platform/shared/app/shell/zsh.nix
    /nix/store/.../platform/shared/app/editor/helix.nix
    /nix/store/.../platform/darwin/app/aerospace.nix
  ];
}
```

______________________________________________________________________

## Data Flow

```
User Config (default.nix)
  ↓
  user.applications = [ "git" "zsh" "helix" ]
  ↓
Home Manager Bootstrap (home-manager.nix)
  ↓
  Detects applications != null
  ↓
  Imports discovery library
  ↓
Discovery System (discovery.nix)
  ↓
  mkApplicationsModule { applications = [...]; }
  ↓
  Resolves app names to paths
  ↓
  Returns { imports = [path1 path2 path3]; }
  ↓
Home Manager Module System
  ↓
  Imports application modules
  ↓
Final User Environment Configuration
```

______________________________________________________________________

## State Transitions

**User Configuration Lifecycle**:

1. **Draft** - User edits `default.nix`, adds/removes apps from array
1. **Evaluation** - `nix flake check` or `just build` evaluates configuration
1. **Validation** - Type system validates list structure, discovery validates app names
1. **Resolution** - Discovery system resolves app names to module paths
1. **Import** - Home Manager imports resolved application modules
1. **Build** - Nix builds user environment with configured applications
1. **Activation** - `home-manager switch` activates new configuration

**State Diagram**:

```
[User Edits] → [Nix Evaluates] → [Type Check] → [Discovery Resolution]
                                       ↓                    ↓
                                  [Type Error]        [Name Error]
                                       ↓                    ↓
                                  [Build Fails]       [Build Fails]
                                  
[Discovery Resolution] → [Module Import] → [Nix Build] → [HM Activation]
                                                ↓
                                          [Build Success]
                                                ↓
                                        [Environment Ready]
```

______________________________________________________________________

## Validation Rules Summary

| Field | Required | Type | Validation | Error Handling |
|-------|----------|------|------------|----------------|
| `user.applications` | No | `nullOr (listOf str)` | Type system + discovery | Fail fast with clear error |
| Array elements | If list provided | `str` | Discovery system | Suggestions for typos |
| Application exists | If name provided | - | Discovery registry | List available apps |
| Platform compatibility | If platform-specific | - | Discovery graceful skip | Skip unavailable (user configs) |

______________________________________________________________________

## Relationships

```
User Configuration
  ├── Has optional applications field
  │   └── Contains list of application names
  │
  └── Processed by Home Manager Bootstrap
      └── Invokes Discovery System
          └── Resolves applications to module paths
              └── Returns import list to Home Manager
```

______________________________________________________________________

## Constraints

1. **Type Safety**: Nix type system enforces list of strings structure
1. **Name Validity**: Discovery system validates against application registry
1. **Platform Compatibility**: Discovery handles platform-specific apps automatically
1. **Backward Compatibility**: Field is optional, null by default
1. **No Side Effects**: Pure functional transformation, no external state modification

______________________________________________________________________

## Extension Points

Future features can extend this model:

1. **Application Options**: Per-app configuration in user structure

   ```nix
   user.applications = {
     git.enable = true;
     git.config = { ... };
   };
   ```

1. **Conditional Applications**: Platform-specific app lists

   ```nix
   user.applications = {
     shared = [ "git" "zsh" ];
     darwin = [ "aerospace" ];
     nixos = [ "i3" ];
   };
   ```

1. **Application Groups**: Named bundles of applications

   ```nix
   user.applicationGroups = [ "development" "productivity" ];
   ```

**Note**: These are potential future enhancements, not part of this feature.

______________________________________________________________________

## Non-Functional Properties

**Performance**:

- Evaluation time: O(n) where n = number of applications
- Same as explicit discovery calls (no performance change)
- Discovery system caches application registry per evaluation

**Scalability**:

- Supports arbitrary number of applications
- Tested with 40-50 applications across 3 users
- Linear scaling with application count

**Maintainability**:

- Single source of truth for application list
- Easy to add/remove applications (edit array)
- Type system prevents common mistakes
- Clear error messages guide fixes

______________________________________________________________________

## Summary

The data model is minimal and leverages existing infrastructure:

- **One new field**: `user.applications` (optional list of strings)
- **Zero new entities**: Uses existing discovery system registry
- **Pure functional**: No persistent state, evaluation-time only
- **Type safe**: Nix type system enforces structure
- **Validated**: Discovery system validates application names
- **Backward compatible**: Optional field with null default
