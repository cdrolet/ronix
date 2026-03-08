# Data Model: User Locale Configuration

**Feature**: 018-user-locale-config\
**Date**: 2025-11-15

## Overview

This feature extends the user configuration entity with optional locale fields and introduces a keyboard layout translation entity for platform-agnostic keyboard layout management.

## Entities

### 1. User Configuration

**Purpose**: Represents per-user settings including locale preferences

**Location**: `user/{username}/default.nix`

**Attributes**:

| Field | Type | Required | Format | Description |
|-------|------|----------|--------|-------------|
| `name` | string | Yes | alphanumeric | User's system username (existing) |
| `email` | string | Yes | email format | User's email address (existing) |
| `fullName` | string | Yes | text | User's full display name (existing) |
| `languages` | list of strings | No | ISO 639-1 + ISO 3166-1 | Ordered language preferences (e.g., `["en-CA" "fr-CA"]`) |
| `keyboardLayout` | list of strings | No | platform-agnostic names | Ordered keyboard layout preferences (e.g., `["us" "canadian-french"]`) |
| `timezone` | string | No | IANA timezone identifier | User's timezone (e.g., `"America/Toronto"`) |
| `locale` | string | No | POSIX locale | User's regional locale (e.g., `"en_CA.UTF-8"`) |

**Relationships**:

- Consumed by darwin platform settings module (1:1)
- Consumed by Home Manager user environment (1:1)

**Validation Rules**:

- All locale fields (`languages`, `keyboardLayout`, `timezone`, `locale`) are optional
- `languages`: Must be non-empty array if specified
- `keyboardLayout`: Must contain valid platform-agnostic layout names from registry
- `timezone`: Must be valid IANA timezone identifier if specified
- `locale`: Must be valid POSIX locale identifier if specified

**Example**:

```nix
{
  user = {
    name = "cdrokar";
    email = "charles@example.com";
    fullName = "Charles Drolet";
    
    # Optional locale configuration
    languages = [ "en-CA" "fr-CA" ];
    keyboardLayout = [ "us" "canadian-french" ];
    timezone = "America/Toronto";
    locale = "en_CA.UTF-8";
  };
}
```

**State Transitions**: N/A (static configuration)

______________________________________________________________________

### 2. Keyboard Layout Translation Registry

**Purpose**: Maps platform-agnostic keyboard layout names to platform-specific identifiers

**Location**: `platform/darwin/lib/keyboard-layout-translation.nix`

**Structure**:

```nix
{
  darwin = {
    <agnostic-name> = <darwin-layout-object>;
    # ...
  };
  # Future: nixos = { ... };
}
```

**Attributes (per layout entry)**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `agnostic-name` | attribute key | Yes | Platform-agnostic identifier (e.g., "us", "canadian-french") |
| `id` | int or null | Yes | macOS KeyboardLayout ID (null if not yet discovered) |
| `name` | string | Yes | macOS display name for layout |

**Relationships**:

- Referenced by darwin locale settings module (many:1 - many layouts to one registry)

**Validation Rules**:

- `agnostic-name`: Must be lowercase, kebab-case
- `id`: Must be non-negative integer or null (pending discovery)
- `name`: Must match macOS keyboard layout name exactly

**Initial Registry**:

```nix
{
  darwin = {
    us = { id = 0; name = "U.S."; };
    canadian = { id = 29; name = "Canadian"; };
    canadian-french = { id = null; name = "Canadian-CSA"; };
    british = { id = null; name = "British"; };
    dvorak = { id = null; name = "Dvorak"; };
    colemak = { id = null; name = "Colemak"; };
    french = { id = null; name = "French"; };
    german = { id = null; name = "German"; };
    spanish = { id = null; name = "Spanish"; };
    brazilian = { id = null; name = "Brazilian"; };
  };
}
```

**State Transitions**: N/A (static registry, updated manually when new layouts added)

______________________________________________________________________

### 3. Darwin Locale Configuration

**Purpose**: Platform-specific locale settings generated from user configuration

**Location**: `platform/darwin/settings/locale.nix`

**Not a Data Entity**: This is a derived configuration, not stored data. Generated at build time from user configuration.

**Input**: User configuration (`userContext.user`)

**Output**: nix-darwin system configuration options

**Transformation Logic**:

| User Field | Darwin Module Option | Transformation |
|-----------|---------------------|----------------|
| `languages` | `system.defaults.CustomUserPreferences."Apple Global Domain".AppleLanguages` | Direct array copy |
| `keyboardLayout` | `system.defaults.CustomUserPreferences."com.apple.HIToolbox".AppleSelectedInputSources` | Translate via registry → layout objects |
| `timezone` | `time.timeZone` | Direct string copy |
| `locale` | `system.defaults.CustomUserPreferences."Apple Global Domain".AppleLocale` | Strip `.UTF-8` suffix |
| `locale` (implicit) | `system.defaults.NSGlobalDomain.AppleMeasurementUnits` | Derive metric/imperial from locale region |
| `locale` (implicit) | `system.defaults.NSGlobalDomain.AppleMetricUnits` | Derive 0/1 from locale region |

**Example Transformation**:

**Input (user config)**:

```nix
{
  languages = [ "en-CA" "fr-CA" ];
  keyboardLayout = [ "us" "canadian-french" ];
  timezone = "America/Toronto";
  locale = "en_CA.UTF-8";
}
```

**Output (darwin configuration)**:

```nix
{
  time.timeZone = "America/Toronto";
  
  system.defaults.CustomUserPreferences."Apple Global Domain" = {
    AppleLanguages = [ "en-CA" "fr-CA" ];
    AppleLocale = "en_CA";
  };
  
  system.defaults.CustomUserPreferences."com.apple.HIToolbox" = {
    AppleSelectedInputSources = [
      {
        InputSourceKind = "Keyboard Layout";
        "KeyboardLayout ID" = 0;
        "KeyboardLayout Name" = "U.S.";
      }
      {
        InputSourceKind = "Keyboard Layout";
        "KeyboardLayout ID" = null;  # Needs discovery
        "KeyboardLayout Name" = "Canadian-CSA";
      }
    ];
  };
  
  system.defaults.NSGlobalDomain = {
    AppleMeasurementUnits = "Centimeters";  # Derived from en_CA
    AppleMetricUnits = 1;
  };
}
```

______________________________________________________________________

## Type Definitions (Nix Module System)

### User Configuration Type

```nix
# user/shared/lib/types.nix (or inline in darwin.nix)
{
  user = {
    name = lib.types.str;
    email = lib.types.str;
    fullName = lib.types.str;
    
    # New optional locale fields
    languages = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      description = "Ordered list of preferred languages (ISO 639-1 + ISO 3166-1 format, e.g., 'en-CA', 'fr-CA')";
      example = [ "en-CA" "fr-CA" ];
    };
    
    keyboardLayout = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      description = "Ordered list of keyboard layouts using platform-agnostic names (e.g., 'us', 'canadian-french')";
      example = [ "us" "canadian-french" ];
    };
    
    timezone = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "IANA timezone identifier (e.g., 'America/Toronto', 'Europe/Paris')";
      example = "America/Toronto";
    };
    
    locale = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "POSIX locale identifier (e.g., 'en_CA.UTF-8', 'fr_CA.UTF-8')";
      example = "en_CA.UTF-8";
    };
  };
}
```

### Keyboard Layout Object Type

```nix
# platform/darwin/lib/types.nix
keyboardLayoutType = lib.types.submodule {
  options = {
    id = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.unsigned;
      description = "macOS KeyboardLayout ID (null if not yet discovered)";
    };
    
    name = lib.mkOption {
      type = lib.types.str;
      description = "macOS keyboard layout display name";
    };
  };
};
```

______________________________________________________________________

## Data Flow

```
1. User edits user/{username}/default.nix
   ↓
2. Flake builds configuration
   ↓
3. darwin.nix passes userContext to darwin settings
   ↓
4. locale.nix reads userContext.user.{languages,keyboardLayout,timezone,locale}
   ↓
5. locale.nix imports keyboard-layout-translation.nix
   ↓
6. locale.nix translates keyboardLayout names → darwin layout objects
   ↓
7. locale.nix generates darwin system.defaults configuration
   ↓
8. darwin-rebuild applies configuration to system
   ↓
9. User logs out/in (for keyboard layouts) or sees immediate changes (language/timezone)
```

______________________________________________________________________

## Validation

### Build-Time Validation

**User Configuration**:

- Type checking via Nix module system
- Non-empty array check for `languages` if specified
- Keyboard layout name validation against registry

**Keyboard Layout Translation**:

- Unknown layout name → build error with suggestion
- Missing layout ID (null) → warning, layout object created with null ID

**Example Error Messages**:

```
error: Unknown keyboard layout: 'canadian-french-csa'
Did you mean one of: canadian-french, canadian, french?
Available layouts: us, canadian, canadian-french, british, dvorak, colemak, french, german, spanish, brazilian
```

### Runtime Validation

**After activation**:

```bash
# Verify settings applied correctly
defaults read NSGlobalDomain AppleLanguages
defaults read NSGlobalDomain AppleLocale  
defaults read com.apple.HIToolbox AppleSelectedInputSources
sudo systemsetup -gettimezone
```

**Multi-User Validation**:

- Build configs for all users with different settings
- Verify no interference between user configurations

______________________________________________________________________

## Constraints

### Size Constraints

- `languages` array: Max 10 languages (reasonable preference list)
- `keyboardLayout` array: Max 10 layouts (macOS UI limit ~8-10 practical layouts)
- `timezone`: Single value only (no array)
- `locale`: Single value only (no array)

### Format Constraints

- Language codes: Must match ISO 639-1 + ISO 3166-1 format (`"en-CA"`, `"fr-CA"`, etc.)
- Keyboard layout names: Must be lowercase, kebab-case, exist in registry
- Timezone: Must be valid IANA identifier (no custom timezones)
- Locale: Must be POSIX format (`language_REGION` or `language_REGION.encoding`)

### Platform Constraints

- Darwin only in first implementation
- Keyboard layout IDs are darwin-specific (won't work on NixOS)
- Translation layer architecture supports future platforms

______________________________________________________________________

## Evolution Strategy

### Adding New Keyboard Layouts

1. User requests layout `"new-layout"`
1. Developer manually configures layout in macOS System Preferences
1. Developer runs `defaults read com.apple.HIToolbox AppleSelectedInputSources`
1. Developer extracts KeyboardLayout ID
1. Developer adds to `keyboard-layout-translation.nix`:
   ```nix
   "new-layout" = { id = <discovered-id>; name = "<macOS-name>"; };
   ```
1. User can now use `keyboardLayout = [ "new-layout" ]`

### Adding Future Platforms

1. Create `platform/nixos/lib/keyboard-layout-translation.nix`
1. Add `nixos = { ... }` section to translation registry
1. Map platform-agnostic names to NixOS keyboard layout identifiers
1. Create `platform/nixos/settings/locale.nix` consuming user config
1. User configs unchanged (platform-agnostic names work on both platforms)

### Deprecation Strategy

If locale fields move to different location in future:

1. Add new location with same field names
1. Keep old location as deprecated (warning)
1. Copy values from old → new automatically
1. Remove old location after migration period (1-2 releases)
