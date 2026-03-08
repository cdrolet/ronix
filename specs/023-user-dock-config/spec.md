# Feature Specification: User Dock Configuration

**Feature Branch**: `023-user-dock-config`
**Created**: 2025-12-18
**Status**: Ready for Planning
**Input**: User description: "in user configuration, add a new optional field: docked which is an array similar to applications. it will define the applications, folders, and their exact order in a dock."

## Research Summary

Research has been completed. See [research.md](./research.md) for full details.

**Key findings**:

- **Darwin**: Use dockutil with filesystem search in `/Applications`, `/System/Applications`
- **GNOME**: Use gsettings with `.desktop` file names
- **Trash**: Darwin handles automatically; GNOME requires custom `.desktop` file
- **Timing**: Dock config runs in activation phase after packages installed

## Problem Statement

The core challenge is:

**How can users specify dock items (applications and folders) in a platform-agnostic way that works across darwin, GNOME, KDE, and other desktop environments without leaking system-specific paths into user configuration?**

### Key Challenges

1. **Application Path Resolution**: Different platforms store applications in different locations

   - Darwin: `/Applications/Obsidian.app`, `/System/Applications/Mail.app`
   - Linux (Nix): `/nix/store/.../bin/obsidian`, or via `.desktop` files
   - GNOME/KDE: Reference apps by `.desktop` file names (e.g., `org.gnome.Nautilus.desktop`)

1. **Folder Path Resolution**: User folders have different base paths

   - Darwin: `/Users/<username>/Downloads`
   - Linux: `/home/<username>/Downloads`

1. **Discovery Timing**: App paths can only be resolved after all applications have been installed by previous modules

1. **User Experience**: Users know app names ("obsidian", "firefox"), not paths

______________________________________________________________________

## Proposed User Configuration Syntax

### Field Rename

The field is renamed from `docked_applications` to `docked` to reflect that it can contain both applications and folders.

### Syntax Proposal

```nix
{
  user = {
    name = "cdrokar";
    applications = ["*"];
    
    docked = [
      # Applications (plain names - resolved by system dock module)
      "zen"
      "brave" 
      "mail"
      
      # Separator
      "|"
      
      # Development apps
      "zed"
      "ghostty"
      
      # Thick separator (if supported)
      "||"
      
      # Folders (prefixed with "/" to indicate folder)
      "/Downloads"
      "/Documents"
    ];
  };
}
```

### Syntax Rules

| Entry Type | Syntax | Example | Resolution |
|------------|--------|---------|------------|
| Application | plain name | `"obsidian"` | System resolves to platform path |
| Folder | `/` prefix | `"/Downloads"` | First try `$HOME/Downloads`, then try `/Downloads` as absolute path |
| Trash | `<trash>` | `"<trash>"` | System trash/bin (platform-specific) |
| Standard separator | `\|` | `"\|"` | Platform-specific spacer |
| Thick separator | `\|\|` | `"\|\|"` | Thick spacer or fallback to standard |

**Special syntax rationale**:

- `<trash>` uses angle brackets to clearly distinguish system items from app names
- This pattern can be extended for future system items (e.g., `<launchpad>` on darwin)
- Angle brackets are visually distinct and unlikely to conflict with app/folder names

______________________________________________________________________

## Research Questions

### RQ1: Application Path Resolution Strategy

**Question**: How should the dock module resolve application names to platform-specific paths?

**Options to Research**:

| Option | Approach | Pros | Cons |
|--------|----------|------|------|
| A | Search known locations | Simple, no metadata needed | May miss apps in unusual locations |
| B | Use desktop metadata (Feature 019) | Already has paths defined | Requires all docked apps to have metadata |
| C | Query package manager | Accurate for Nix-installed apps | Doesn't work for system apps (Mail.app) |
| D | Hybrid: metadata → search → skip | Best coverage | More complex implementation |

**Darwin-specific locations to search**:

- `/Applications/*.app`
- `/System/Applications/*.app`
- `/System/Applications/Utilities/*.app`
- `~/Applications/*.app`

**Linux-specific approaches**:

- Search for `.desktop` files in `$XDG_DATA_DIRS/applications/`
- Use `gtk-launch` or similar to find executables

______________________________________________________________________

### RQ2: Folder Path Resolution Strategy

**Question**: How should folder names like `/Downloads` be resolved to full paths?

**Proposed Approach**:

1. If entry starts with `/` but is not an absolute path (e.g., `/Downloads` not `/Users/foo/Downloads`)
1. Treat as a user-relative folder name
1. Resolve to `$HOME/<folder_name>` or platform equivalent

**Darwin**: `/Downloads` → `/Users/<username>/Downloads`
**Linux**: `/Downloads` → `/home/<username>/Downloads`

**Edge cases**:

- What if the folder doesn't exist? Skip silently (same as missing apps)
- What about system folders (e.g., `/Applications`)? Only user folders supported in v1

______________________________________________________________________

### RQ3: GNOME/KDE Dock Configuration

**Question**: How do GNOME and KDE docks reference applications?

**Research needed**:

- GNOME Dash-to-Dock / Ubuntu Dock: Uses `gsettings` with `.desktop` file names
- KDE Plasma: Uses different mechanism (research needed)
- Common `.desktop` file locations and naming conventions

**Example GNOME**:

```bash
gsettings set org.gnome.shell favorite-apps \
  "['org.gnome.Nautilus.desktop', 'firefox.desktop', 'org.gnome.Terminal.desktop']"
```

______________________________________________________________________

### RQ4: Timing and Module Execution Order

**Question**: When should dock configuration run relative to application installation?

**Constraint**: Dock module must run AFTER all applications are installed so paths can be resolved.

**Proposed Solution**:

- Dock module runs in activation phase (after package installation)
- Module searches for apps at activation time, not evaluation time

______________________________________________________________________

### RQ5: Trash/Bin Dock Item

**Question**: How is the system trash handled in docks across platforms?

**Darwin observations**:

- Trash is added to dock by default (rightmost position)
- May need research on whether this is automatic or configurable
- Path: `~/.Trash` but dock representation may be special

**Research needed**:

- Is darwin trash automatically in dock or explicitly added?
- How does GNOME handle trash in dock/dash?
- How does KDE handle trash in panel?
- Is there a `.desktop` file for trash on Linux?

**Proposed syntax**: `"<trash>"` with angle brackets to distinguish from app names

- If present, trash is added at that position
- If absent on darwin, behavior TBD (remove default trash? leave as-is?)
- Angle bracket syntax allows future system items like `<launchpad>`

______________________________________________________________________

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Define Dock Items in User Config (Priority: P1)

A user wants to specify which applications and folders appear in their system dock, directly from their user configuration file, using simple names without platform-specific paths.

**Why this priority**: Core value proposition - user-controlled dock contents in a portable format.

**Independent Test**: Add a `docked` array to user config and verify dock displays those items after activation.

**Acceptance Scenarios**:

1. **Given** a user configuration with `docked = ["zen" "brave" "/Downloads"]`, **When** the system is activated on darwin, **Then** the dock displays Zen.app, Brave Browser.app, and Downloads folder
1. **Given** the same configuration, **When** the system is activated on GNOME, **Then** the GNOME dock displays the equivalent applications and folder
1. **Given** a user configuration without `docked` field, **When** the system is activated, **Then** dock behavior remains unchanged

______________________________________________________________________

### User Story 2 - Visual Separators (Priority: P2)

A user wants to organize dock items into logical groups using visual separators.

**Acceptance Scenarios**:

1. **Given** `docked = ["zen" "|" "zed"]`, **When** activated, **Then** a separator appears between Zen and Zed
1. **Given** `docked = ["zen" "||" "zed"]`, **When** activated on darwin, **Then** a thick separator appears (darwin supports this)
1. **Given** `docked = ["zen" "||" "zed"]`, **When** activated on GNOME, **Then** a standard separator appears (fallback)

______________________________________________________________________

### User Story 3 - Graceful Missing Item Handling (Priority: P2)

Missing applications or folders should be silently skipped.

**Acceptance Scenarios**:

1. **Given** `docked = ["zen" "nonexistent" "brave"]`, **When** activated, **Then** dock shows Zen and Brave only
1. **Given** `docked = ["/NonexistentFolder"]`, **When** activated, **Then** dock is empty, no error raised
1. **Given** an app installed on darwin but not GNOME, **When** same config used on GNOME, **Then** that app is skipped

______________________________________________________________________

### User Story 4 - Trash in Dock (Priority: P3)

A user wants to include the system trash/recycle bin in their dock at a specific position.

**Why this priority**: Trash is a common dock item but has platform-specific behavior. Darwin adds it by default; other platforms may not.

**Independent Test**: Add `"trash"` to docked array and verify trash appears at that position.

**Acceptance Scenarios**:

1. **Given** `docked = ["zen" "|" "<trash>"]`, **When** activated on darwin, **Then** dock shows Zen, separator, and Trash in that order
1. **Given** `docked = ["firefox" "<trash>"]`, **When** activated on GNOME, **Then** dock shows Firefox and Trash (if GNOME supports trash in dock)
1. **Given** `docked = ["zen"]` (no `<trash>`), **When** activated on darwin, **Then** behavior TBD (research needed: remove default trash or leave it?)

______________________________________________________________________

### Edge Cases

- Empty `docked` array: Dock should be cleared/reset
- Only separators: No items added, separators ignored
- Consecutive separators: Collapse to single
- Leading/trailing separators: Ignored
- Duplicate entries: Keep first occurrence only
- App name casing: Case-insensitive matching where platform supports

______________________________________________________________________

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST support an optional `docked` field in user configuration accepting an array of strings
- **FR-002**: Plain string entries MUST be interpreted as application names to be resolved by the platform dock module
- **FR-003**: Entries starting with `/` MUST be resolved as folders using fallback: first try `$HOME/<name>`, then try as absolute path
- **FR-004**: `"|"` MUST be interpreted as a standard visual separator
- **FR-005**: `"||"` MUST be interpreted as a thick separator, falling back to standard if unsupported
- **FR-006**: Missing applications MUST be silently skipped without errors
- **FR-007**: Missing folders MUST be silently skipped without errors
- **FR-008**: Order of valid items in dock MUST match order in configuration array
- **FR-009**: Darwin dock module MUST resolve app names to `/Applications/*.app` or `/System/Applications/*.app` paths
- **FR-010**: GNOME dock module MUST resolve app names to `.desktop` file references
- **FR-011**: Platforms without dock modules MUST ignore the `docked` field without error
- **FR-012**: Dock module MUST execute after all application installation modules complete
- **FR-013**: Consecutive separators MUST be collapsed to a single separator
- **FR-014**: Entries matching `<name>` pattern (angle brackets) MUST be interpreted as system items
- **FR-015**: The system item `"<trash>"` MUST be interpreted as the system trash/recycle bin
- **FR-016**: System items MUST be added to dock at the position specified in the array
- **FR-017**: Unrecognized system items (e.g., `"<unknown>"`) MUST be silently skipped

### Key Entities

- **Dock Entry**: A string in the `docked` array - app name, folder reference, system item, or separator
- **System Item**: Entry with angle brackets (e.g., `<trash>`, `<launchpad>`) representing platform-specific system elements
- **App Name**: Plain string (e.g., "obsidian") resolved to platform path at activation
- **Folder Reference**: String starting with `/` (e.g., "/Downloads") resolved to user folder
- **Dock Module**: Platform/family-specific module that reads `docked` and applies configuration

______________________________________________________________________

## Success Criteria *(mandatory)*

- **SC-001**: Users define dock layout in 1-10 lines without any platform-specific paths
- **SC-002**: Same `docked` configuration works on darwin and GNOME (minus platform-specific apps)
- **SC-003**: 100% of resolvable items appear in dock in correct order
- **SC-004**: 0% of unresolvable items cause errors or warnings
- **SC-005**: Darwin dock no longer has hardcoded apps in settings/dock.nix

______________________________________________________________________

## Assumptions

- App names use the same conventions as the `applications` field (discovery system names)
- Darwin dock library already exists with helper functions
- GNOME favorites can be set via dconf/gsettings
- User folders follow XDG conventions on Linux, standard locations on darwin

## Out of Scope

- Dock position, size, or behavior settings (remain in platform settings)
- Per-host dock customization (dock config is per-user)
- Dynamic dock items based on running applications
- Folder view options (fan, grid, etc.) - platform-specific defaults used

______________________________________________________________________

## Research Action Items

1. **Investigate darwin app resolution**: Test searching `/Applications`, `/System/Applications` for `.app` bundles by name
1. **Investigate GNOME dock**: Document gsettings schema and `.desktop` file discovery
1. **Investigate KDE dock**: Document Plasma panel configuration mechanism
1. **Prototype folder resolution**: Test `$HOME` expansion for `/Downloads` → `/Users/x/Downloads`
1. **Review Feature 019 desktop metadata**: Determine if `paths.darwin`/`paths.nixos` can be leveraged
1. **Document execution order**: Confirm dock module can run in activation phase after packages installed
1. **Investigate darwin trash**: Is trash automatically in dock? Can it be removed/repositioned?
1. **Investigate GNOME trash**: How to add trash to GNOME dock/dash? Is there a `.desktop` file?
1. **Investigate KDE trash**: How to add trash to KDE panel?
