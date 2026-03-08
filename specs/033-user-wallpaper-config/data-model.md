# Data Model: User Wallpaper Configuration

**Feature**: 033-user-wallpaper-config\
**Date**: 2025-12-30\
**Phase**: Phase 1 - Design

## Overview

The wallpaper configuration feature introduces a single user-level field for specifying desktop wallpaper file paths. The configuration is platform-agnostic at the user level, with platform-specific implementations handling the actual wallpaper application.

______________________________________________________________________

## Entity: User Wallpaper Configuration

### Attributes

| Attribute | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `wallpaper` | String (file path) | No | `null` | Absolute or home-relative path to wallpaper image file |

### Validation Rules

1. **Path Format**:

   - MUST be absolute path (e.g., `/Users/username/Pictures/wallpaper.jpg`)
   - OR home-relative with tilde (e.g., `~/Pictures/wallpaper.jpg`)
   - Tilde will be expanded to `config.home.homeDirectory`

1. **File Existence**:

   - File MAY not exist at build time (warning logged if missing)
   - Runtime validation checks existence before applying
   - Missing files result in graceful skip (no activation failure)

1. **File Format**:

   - SHOULD have supported image extension: `.jpg`, `.jpeg`, `.png`, `.heic`, `.webp`
   - Unsupported extensions trigger build warning but don't block
   - Platform determines final format compatibility

1. **Path Constraints**:

   - No length limit
   - Supports spaces and special characters (properly escaped in shell)
   - Must be readable by user (permission check at runtime)

### State Transitions

Wallpaper configuration has no complex state - it's a static file reference that changes only when user updates their configuration.

**State flow:**

1. **Unconfigured** (`wallpaper = null`) → System default wallpaper remains
1. **Configured** → Path validated and applied at activation
1. **Invalid** (missing/unreadable file) → Warning logged, wallpaper unchanged

______________________________________________________________________

## Platform-Specific Data

### Darwin (macOS)

**Internal representation:**

- Absolute file path (string)
- Stored in user defaults database by macOS
- Applied via osascript AppleScript command

**Platform-specific fields:**

- None (uses base wallpaper field)

**Storage location:**

- macOS manages wallpaper settings in `~/Library/Preferences/com.apple.desktop.plist`
- Not directly managed by Nix (set via osascript during activation)

### GNOME Desktop

**Internal representation:**

- File URI string: `file:///absolute/path/to/wallpaper.jpg`
- Stored in dconf database (`~/.config/dconf/user`)

**Platform-specific fields:**

- `picture-uri` (light mode wallpaper)
- `picture-uri-dark` (dark mode wallpaper)
- `picture-options` (display mode: zoom, scaled, centered, spanned)

**Storage location:**

- dconf database: `org/gnome/desktop/background/picture-uri`
- Set declaratively via Home Manager's `dconf.settings`

______________________________________________________________________

## User Configuration Schema

### Minimal Configuration

```nix
{
  user = {
    name = "username";
    wallpaper = "/Users/username/Pictures/wallpaper.jpg";
  };
}
```

### With Tilde Expansion

```nix
{
  user = {
    name = "username";
    wallpaper = "~/Pictures/mountain-view.png";
  };
}
```

### Unconfigured (Default Behavior)

```nix
{
  user = {
    name = "username";
    # wallpaper not specified - system default remains
  };
}
```

______________________________________________________________________

## Platform Implementation Data

### Darwin Settings Module

**File**: `system/darwin/settings/wallpaper.nix`

**Data flow:**

1. Read `config.user.wallpaper`
1. Expand tilde to `${config.home.homeDirectory}`
1. Validate file existence at runtime
1. Execute osascript with absolute path
1. osascript updates macOS defaults database

**Activation script data:**

```bash
WALLPAPER="/absolute/path/to/wallpaper.jpg"
osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"$WALLPAPER\""
```

### GNOME Settings Module

**File**: `system/shared/family/gnome/settings/wallpaper.nix`

**Data flow:**

1. Read `config.user.wallpaper`
1. Expand tilde to `${config.home.homeDirectory}`
1. Convert to file URI: `file:///absolute/path`
1. Set dconf values via Home Manager
1. GNOME reads dconf and applies wallpaper

**dconf data structure:**

```nix
dconf.settings = {
  "org/gnome/desktop/background" = {
    picture-uri = "file:///home/username/Pictures/wallpaper.jpg";
    picture-uri-dark = "file:///home/username/Pictures/wallpaper.jpg";
    picture-options = "zoom";
  };
};
```

______________________________________________________________________

## Validation Data

### Build-Time Warnings

**Warning conditions:**

```nix
warnings = []
  ++ lib.optional (wallpaper != null && !builtins.pathExists expandedPath)
     "Wallpaper file not found: ${expandedPath}"
  ++ lib.optional (wallpaper != null && !hasValidExtension)
     "Wallpaper has unsupported extension. Supported: .jpg, .jpeg, .png, .heic, .webp"
;
```

**Validation data fields:**

- `wallpaper` (user-provided string)
- `expandedPath` (tilde-expanded absolute path)
- `fileExists` (boolean from `builtins.pathExists`)
- `hasValidExtension` (boolean from extension check)

### Runtime Validation

**Validation checks:**

1. File existence: `[ -f "$WALLPAPER_PATH" ]`
1. File readability: `[ -r "$WALLPAPER_PATH" ]` (optional)
1. MIME type validation: `file -b --mime-type` (optional, GNOME only)

**Validation outcomes:**

- ✅ Valid → Wallpaper applied
- ❌ Missing → Warning logged, activation continues
- ❌ Unreadable → Warning logged, activation continues

______________________________________________________________________

## Helper Data Structures

### Path Expansion

```nix
# Input: user-provided path (may contain tilde)
input = "~/Pictures/wallpaper.jpg"

# Processing
isTildeRelative = lib.hasPrefix "~/" input
relativePart = lib.removePrefix "~/" input
homeDirectory = config.home.homeDirectory

# Output: absolute path
output = if isTildeRelative 
         then "${homeDirectory}/${relativePart}"
         else input
# Result: "/Users/username/Pictures/wallpaper.jpg"
```

### Extension Validation

```nix
# Input
wallpaperPath = "/Users/username/Pictures/image.jpg"

# Valid extensions list
validExts = [".jpg" ".jpeg" ".png" ".heic" ".webp"]

# Normalization
normalized = lib.toLower wallpaperPath  # Case-insensitive

# Validation
hasValidExt = lib.any (ext: lib.hasSuffix ext normalized) validExts
# Result: true
```

### URI Formatting (GNOME)

```nix
# Input: absolute file path
filePath = "/home/username/Pictures/wallpaper.jpg"

# URI construction
fileUri = "file://${filePath}"

# Result: "file:///home/username/Pictures/wallpaper.jpg"
# Note: Three slashes total (two from file://, one from absolute path starting with /)
```

______________________________________________________________________

## Relationships and Dependencies

### User Configuration → Platform Settings

```
┌─────────────────────────┐
│  User Configuration     │
│  (user.wallpaper)       │
└───────────┬─────────────┘
            │
            ├─────────────────────────┐
            │                         │
            ▼                         ▼
┌─────────────────────┐   ┌─────────────────────┐
│  Darwin Settings    │   │  GNOME Settings     │
│  (osascript)        │   │  (dconf.settings)   │
└─────────────────────┘   └─────────────────────┘
```

### Data Flow Diagram

```
User Config (Nix)
    │
    ├─ wallpaper = "~/Pictures/image.jpg"
    │
    ▼
Path Expansion
    │
    ├─ expandedPath = "/Users/username/Pictures/image.jpg"
    │
    ▼
Validation
    │
    ├─ fileExists: true/false
    ├─ validExtension: true/false
    ├─ warnings: [...] (if issues detected)
    │
    ▼
Platform Implementation
    │
    ├─ Darwin: osascript activation script
    │   └─ Sets all desktops to wallpaper
    │
    └─ GNOME: dconf.settings
        └─ picture-uri and picture-uri-dark set
```

______________________________________________________________________

## Configuration Lifecycle

### 1. Build Time (Nix Evaluation)

**Data processed:**

- User configuration parsed
- Tilde expansion performed
- File existence checked (if path accessible)
- Warnings generated for validation failures

**Outputs:**

- Expanded wallpaper path
- Warnings list (displayed during build)
- Platform-specific activation scripts/dconf settings

### 2. Activation Time (Home Manager Apply)

**Data processed:**

- Absolute wallpaper path from build
- Runtime file existence check
- Platform-specific API calls

**Outputs:**

- Darwin: macOS defaults database updated
- GNOME: dconf database updated
- Console warnings for missing files

### 3. Runtime (Desktop Environment)

**Data processed:**

- macOS reads from defaults database
- GNOME reads from dconf database

**Outputs:**

- Wallpaper displayed on all connected monitors

______________________________________________________________________

## Example Data Instances

### Example 1: Valid Darwin Configuration

**Input:**

```nix
user.wallpaper = "~/Pictures/macos-wallpaper.jpg";
```

**Processed data:**

```nix
expandedPath = "/Users/alice/Pictures/macos-wallpaper.jpg"
fileExists = true
hasValidExt = true
warnings = []
```

**Activation script data:**

```bash
WALLPAPER="/Users/alice/Pictures/macos-wallpaper.jpg"
osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"$WALLPAPER\""
```

### Example 2: Valid GNOME Configuration

**Input:**

```nix
user.wallpaper = "/home/bob/Pictures/linux-wallpaper.png";
```

**Processed data:**

```nix
expandedPath = "/home/bob/Pictures/linux-wallpaper.png"
fileUri = "file:///home/bob/Pictures/linux-wallpaper.png"
fileExists = true
hasValidExt = true
warnings = []
```

**dconf data:**

```nix
"org/gnome/desktop/background" = {
  picture-uri = "file:///home/bob/Pictures/linux-wallpaper.png";
  picture-uri-dark = "file:///home/bob/Pictures/linux-wallpaper.png";
  picture-options = "zoom";
}
```

### Example 3: Invalid Configuration (Missing File)

**Input:**

```nix
user.wallpaper = "~/Pictures/nonexistent.jpg";
```

**Processed data:**

```nix
expandedPath = "/Users/charlie/Pictures/nonexistent.jpg"
fileExists = false
hasValidExt = true
warnings = ["Wallpaper file not found: /Users/charlie/Pictures/nonexistent.jpg"]
```

**Activation behavior:**

- Build succeeds with warning
- Activation script checks `[ -f ]`, finds false
- Logs warning to stderr
- Skips wallpaper setting (system default remains)

______________________________________________________________________

## Summary

The wallpaper data model is intentionally simple:

- **Single user field**: `user.wallpaper` (string)
- **Platform-agnostic**: Same syntax works on darwin and GNOME
- **Validation-focused**: Warnings instead of failures
- **Path-based**: References external files, not Nix store derivations
- **Declarative**: Set once, applied automatically at activation

Platform implementations handle the complexity of translating this simple field into platform-specific wallpaper APIs.
