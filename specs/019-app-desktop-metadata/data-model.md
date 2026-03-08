# Data Model: Application Desktop Metadata

**Feature**: 019-app-desktop-metadata\
**Created**: 2025-11-16\
**Purpose**: Define the structure and relationships of desktop metadata within application configurations

## Overview

Desktop metadata extends application configuration files with optional desktop integration information. The data model is designed to be platform-agnostic in structure while supporting platform-specific values (desktop paths).

## Entity Definitions

### 1. Desktop Metadata Block (Optional)

The desktop metadata block is an optional attribute set added to application configuration files.

**Attributes**:

- `paths`: Platform-specific desktop paths (attribute set, required if associations or autostart used)
- `associations`: File extensions handled by the application (list of strings, optional)
- `autostart`: Whether to launch at login (boolean, optional, default: false)

**Validation Rules**:

- If `associations` is defined and non-empty, `paths` MUST contain a path for the active platform
- If `autostart` is true, `paths` MUST contain a path for the active platform
- If neither `associations` nor `autostart` are specified, `paths` may be omitted
- The entire desktop metadata block is optional (applications without it work normally)

**Example Structure**:

```nix
{
  desktop = {
    paths = {
      darwin = "/Applications/Zed.app";
      nixos = "${pkgs.zed-editor}/bin/zed";
    };
    associations = [ ".json" ".xml" ".yaml" ".nix" ];
    autostart = false;
  };
}
```

### 2. Platform Desktop Paths (Attribute Set)

Maps platform names to application installation paths.

**Structure**: Attribute set where keys are platform names and values are absolute paths

**Attributes**:

- `darwin`: macOS application path (string, optional)
- `nixos`: NixOS application path (string, optional)
- Additional platforms can be added following the same pattern

**Validation Rules**:

- Keys MUST be valid platform identifiers (matching existing platform names)
- Values MUST be non-empty strings representing absolute paths
- At least one platform MUST have a path if the paths attribute is defined
- Only the active platform's path is read during evaluation

**Path Conventions**:

- **Darwin**: Application bundle paths (e.g., `/Applications/App.app`) or binary paths
- **NixOS**: Binary paths (e.g., `${pkgs.app}/bin/app`) or desktop file references
- Paths may use Nix expressions (e.g., `${pkgs.package}`) for store paths

**Example**:

```nix
paths = {
  darwin = "/Applications/Visual Studio Code.app";
  nixos = "${pkgs.vscode}/bin/code";
}
```

### 3. File Associations (List of Strings)

Declares file extensions that should be handled by the application.

**Structure**: List of file extension strings

**Validation Rules**:

- Each extension MUST start with "." (period)
- Extensions SHOULD contain only alphanumeric characters and common separators (-, \_)
- Extensions are case-insensitive on macOS, case-sensitive on Linux
- Empty list is equivalent to omitting the attribute

**Behavior**:

- Platform libraries process associations using native mechanisms:
  - **Darwin**: Register with Launch Services using duti or similar tools
  - **NixOS**: Update XDG MIME associations via mimeapps.list

**Example**:

```nix
associations = [ ".json" ".xml" ".yaml" ".toml" ".nix" ]
```

### 4. Autostart Flag (Boolean)

Controls whether the application launches automatically at user login.

**Type**: Boolean\
**Default**: false (if omitted)

**Validation Rules**:

- MUST be a boolean value (true or false)
- If true, desktop path MUST be defined for the active platform
- If false or omitted, no autostart configuration is generated

**Behavior**:

- Platform libraries create autostart configuration using native mechanisms:
  - **Darwin**: Create LaunchAgent plist file
  - **NixOS**: Create systemd user service or XDG autostart entry

**Example**:

```nix
autostart = true  # Application starts at login
```

## Relationships

```
Application Configuration
│
└── desktop (optional)
    ├── paths (required if associations or autostart used)
    │   ├── darwin (optional)
    │   ├── nixos (optional)
    │   └── ... (extensible)
    │
    ├── associations (optional)
    │   └── [ ".ext1", ".ext2", ... ]
    │
    └── autostart (optional, default: false)
```

## State Transitions

### Application Configuration States

1. **No Desktop Metadata**: Application has no `desktop` attribute

   - State: Normal application configuration
   - Behavior: No desktop integration features
   - Validation: None required

1. **Desktop Metadata with Paths Only**: Application has `desktop.paths` but no associations or autostart

   - State: Desktop metadata declared but unused
   - Behavior: Paths stored but not processed
   - Validation: Path structure validated

1. **Desktop Metadata with Associations**: Application has `desktop.paths` and `desktop.associations`

   - State: File associations requested
   - Behavior: Platform processes associations using path for active platform
   - Validation: Path for active platform MUST exist

1. **Desktop Metadata with Autostart**: Application has `desktop.paths` and `desktop.autostart = true`

   - State: Autostart requested
   - Behavior: Platform creates autostart configuration using path
   - Validation: Path for active platform MUST exist

1. **Desktop Metadata Complete**: Application has all three components

   - State: Full desktop integration
   - Behavior: Both file associations and autostart configured
   - Validation: Path for active platform MUST exist

### Validation Flow

```
Parse application config
    │
    ├─ No desktop attribute? → Valid (state 1)
    │
    └─ Has desktop attribute
        │
        ├─ Has paths?
        │   ├─ No → Check if associations or autostart defined
        │   │       ├─ Yes → ERROR: "Desktop path required"
        │   │       └─ No → Valid (metadata can be empty)
        │   │
        │   └─ Yes → Validate path structure
        │       ├─ Has associations? → Check active platform path exists
        │       │   ├─ Exists → Valid (state 3)
        │       │   └─ Missing → ERROR: "Path for {platform} required"
        │       │
        │       ├─ Has autostart=true? → Check active platform path exists
        │       │   ├─ Exists → Valid (state 4)
        │       │   └─ Missing → ERROR: "Path for {platform} required"
        │       │
        │       └─ Neither associations nor autostart → Valid (state 2)
```

## Platform Processing

Each platform reads desktop metadata and processes it according to platform conventions:

### Darwin Processing

1. **Path Resolution**: Extract `desktop.paths.darwin`
1. **File Associations**:
   - Use duti or Launch Services to register UTIs
   - Map extensions to application bundle identifier
1. **Autostart**:
   - Create LaunchAgent plist in `~/Library/LaunchAgents/`
   - Configure RunAtLoad = true

### NixOS Processing

1. **Path Resolution**: Extract `desktop.paths.nixos`
1. **File Associations**:
   - Update XDG mimeapps.list via Home Manager
   - Map extensions to MIME types
1. **Autostart**:
   - Create systemd user service or XDG autostart entry
   - Enable service for user session

## Data Constraints

### Required Fields

- None at the root level (entire `desktop` attribute is optional)
- If `desktop.associations` is non-empty OR `desktop.autostart` is true:
  - `desktop.paths` MUST exist
  - `desktop.paths.{activePlatform}` MUST exist

### Optional Fields

- `desktop`: Entire desktop metadata block
- `desktop.paths`: Can be omitted if no associations or autostart
- `desktop.associations`: Can be omitted or empty list
- `desktop.autostart`: Can be omitted (defaults to false)

### Field Types

- `desktop`: Attribute set
- `desktop.paths`: Attribute set (platform name → string path)
- `desktop.associations`: List of strings
- `desktop.autostart`: Boolean

### Immutability

- All desktop metadata is evaluated at build time
- No runtime modification allowed (changes require rebuild/activation)
- Platform selection happens at evaluation time (not runtime)

## Error Scenarios

### 1. Missing Desktop Path for Active Platform

**Trigger**: Application declares associations or autostart, but no path for active platform\
**Error Message**: "Application '{app}' requires desktop.paths.{platform} for file associations or autostart"\
**Resolution**: Add path for the active platform or remove associations/autostart

### 2. Invalid File Extension Format

**Trigger**: Association doesn't start with "."\
**Error Message**: "Invalid file extension '{ext}' in {app}: must start with '.'"\
**Resolution**: Correct extension format (e.g., "json" → ".json")

### 3. Invalid Autostart Value

**Trigger**: Autostart is not a boolean\
**Error Message**: "desktop.autostart must be boolean in {app}, got {type}"\
**Resolution**: Use true or false (not string or other type)

### 4. Empty Desktop Path

**Trigger**: Platform path is empty string\
**Error Message**: "desktop.paths.{platform} cannot be empty in {app}"\
**Resolution**: Provide valid path or remove the platform entry

## Examples

### Example 1: Full Desktop Integration (Text Editor)

```nix
{ config, pkgs, lib, ... }:

{
  home.packages = [ pkgs.zed-editor ];
  
  programs.zed-editor = {
    enable = true;
    desktop = {
      paths = {
        darwin = "/Applications/Zed.app";
        nixos = "${pkgs.zed-editor}/bin/zed";
      };
      associations = [ ".txt" ".md" ".json" ".nix" ];
      autostart = false;
    };
  };
}
```

### Example 2: Autostart Only (Password Manager)

```nix
{ config, pkgs, lib, ... }:

{
  home.packages = [ pkgs.bitwarden ];
  
  programs.bitwarden = {
    enable = true;
    desktop = {
      paths = {
        darwin = "/Applications/Bitwarden.app";
        nixos = "${pkgs.bitwarden}/bin/bitwarden";
      };
      autostart = true;
      # No file associations
    };
  };
}
```

### Example 3: File Associations Only (PDF Viewer)

```nix
{ config, pkgs, lib, ... }:

{
  home.packages = [ pkgs.zathura ];
  
  programs.zathura = {
    enable = true;
    desktop = {
      paths = {
        darwin = "/Applications/Zathura.app";
        nixos = "${pkgs.zathura}/bin/zathura";
      };
      associations = [ ".pdf" ".epub" ];
      # autostart defaults to false
    };
  };
}
```

### Example 4: No Desktop Integration (CLI Tool)

```nix
{ config, pkgs, lib, ... }:

{
  home.packages = [ pkgs.ripgrep ];
  
  programs.ripgrep = {
    enable = true;
    # No desktop metadata - CLI tool doesn't need desktop integration
  };
}
```

### Example 5: Platform-Specific Path (Darwin Only)

```nix
{ config, pkgs, lib, ... }:

{
  programs.aerospace = {
    enable = true;
    desktop = {
      paths = {
        darwin = "/Applications/AeroSpace.app";
        # No nixos path - this is a darwin-only app
      };
      autostart = true;
    };
  };
}
```
