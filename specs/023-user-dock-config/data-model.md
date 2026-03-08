# Data Model: User Dock Configuration

**Feature**: 023-user-dock-config
**Date**: 2025-12-18

## Entities

### DockEntry

A single item in the user's `docked` array. Parsed at activation time.

| Field | Type | Description |
|-------|------|-------------|
| raw | String | Original string from user config |
| entryType | Enum | One of: `app`, `folder`, `separator`, `system` |
| value | String | Parsed value (app name, folder path, system item name) |

**Entry Type Detection**:

```
if matches(raw, "^<.+>$")    → system   (e.g., "<trash>")
if matches(raw, "^\|+$")     → separator ("|" or "||")
if startsWith(raw, "/")      → folder   (e.g., "/Downloads")
else                         → app      (e.g., "zen")
```

### ResolvedDockItem

Result of resolving a DockEntry to platform-specific representation.

| Field | Type | Description |
|-------|------|-------------|
| entryType | Enum | Preserved from DockEntry |
| resolved | String? | Platform-specific path/reference (null if not found) |
| position | Int | 1-based position in dock |

**Darwin Resolution**:

| Entry Type | Resolved Value |
|------------|----------------|
| app | `/Applications/Zen.app` or `/System/Applications/Mail.app` |
| folder | `/Users/charles/Downloads` or `/Volumes/Backup` |
| separator | `spacer` or `small-spacer` |
| system:trash | (ignored - darwin manages) |

**GNOME Resolution**:

| Entry Type | Resolved Value |
|------------|----------------|
| app | `zen.desktop` or `org.gnome.Nautilus.desktop` |
| folder | (not supported in GNOME favorites) |
| separator | (not supported in GNOME favorites) |
| system:trash | `trash.desktop` (created if missing) |

### UserDockedConfig

The user configuration field.

```nix
user = {
  name = "cdrokar";
  applications = ["*"];
  
  # NEW FIELD
  docked = [
    "zen"
    "brave"
    "|"
    "zed"
    "ghostty"
    "||"
    "/Downloads"
    "<trash>"
  ];
};
```

| Field | Type | Required | Default |
|-------|------|----------|---------|
| docked | [String] | No | [] (empty = no dock changes) |

## Validation Rules

### V1: Entry Syntax

- Application names: alphanumeric, hyphens, spaces allowed
- Folder paths: must start with `/`
- Separators: exactly `|` or `||`
- System items: `<name>` format, known items only

### V2: Known System Items

| Item | Darwin | GNOME | KDE |
|------|--------|-------|-----|
| `<trash>` | No-op | Creates trash.desktop | TBD |
| `<launchpad>` | Future | N/A | N/A |

### V3: Folder Path Validation

1. If path starts with `/` but not absolute (e.g., `/Downloads`):
   - Try `$HOME/<path>` first
   - Fall back to `/<path>` as absolute
1. Skip if neither path exists

### V4: Consecutive Separator Handling

```
Input:  ["zen", "|", "|", "brave"]
Output: ["zen", "|", "brave"]  # Collapsed to single separator
```

### V5: Edge Separator Handling

```
Input:  ["|", "zen", "brave", "|"]
Output: ["zen", "brave"]  # Leading/trailing separators removed
```

## State Transitions

### Activation Flow

```
User Config (docked array)
    ↓ parse
List<DockEntry>
    ↓ validate (remove invalid entries)
List<DockEntry> (valid only)
    ↓ collapse separators
List<DockEntry> (normalized)
    ↓ resolve (platform-specific)
List<ResolvedDockItem> (with resolved paths)
    ↓ filter (remove unresolved)
List<ResolvedDockItem> (resolvable only)
    ↓ generate
Platform Activation Script
```

### Empty Dock Behavior

| Input | Darwin | GNOME |
|-------|--------|-------|
| `docked = []` | Clear all items | Clear favorites |
| `docked` not specified | No changes | No changes |

## Nix Type Definitions

```nix
# In user options module
options.user.docked = lib.mkOption {
  type = lib.types.listOf lib.types.str;
  default = [];
  description = ''
    Dock items in display order. Supports:
    - Application names: "zen", "firefox", "mail"
    - Folders: "/Downloads", "/Documents"  
    - Separators: "|" (standard), "||" (thick)
    - System items: "<trash>"
    
    Missing items are silently skipped.
  '';
  example = [
    "zen" "brave" "|" "zed" "ghostty" "/Downloads" "<trash>"
  ];
};
```

## Platform Module Interfaces

### Darwin Dock Module

```nix
# system/darwin/lib/dock.nix additions

# Resolve app name to .app path
# Type: String -> String -> String?
resolveAppPath = appName: userName: ...;

# Resolve folder entry to full path
# Type: String -> String -> String?
resolveFolderPath = folderEntry: userName: ...;

# Parse docked entry to structured form
# Type: String -> { type: String, value: String }
parseDockEntry = entry: ...;

# Generate complete dock activation script from user config
# Type: [String] -> String -> String
mkDockFromUserConfig = dockedList: userName: ...;
```

### GNOME Dock Module

```nix
# system/shared/family/gnome/lib/dock.nix

# Resolve app name to .desktop file name
# Type: String -> String?
resolveDesktopFile = appName: ...;

# Generate favorites list from docked config
# Type: [String] -> [String]
mkFavoritesFromDocked = dockedList: ...;

# Create trash.desktop if needed
# Type: Bool -> AttrSet
mkTrashDesktopFile = includeTrash: ...;
```
