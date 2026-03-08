# Research: Complete Dock Migration from Dotfiles

**Feature**: 007-complete-dock-migration\
**Date**: 2025-10-27\
**Status**: Complete

______________________________________________________________________

## Overview

This document resolves all technical unknowns identified in the implementation plan regarding the migration of Dock configuration from dotfiles to nix-darwin. Four key research areas were investigated:

1. Mapping Dock preferences to nix-darwin options
1. Verifying application paths from dotfiles
1. Reviewing helper library functions from spec 006
1. Determining folder view options for Downloads

______________________________________________________________________

## Decision 1: nix-darwin Options vs Activation Scripts Split

### Question

Which of the 14 Dock preferences from dotfiles have corresponding nix-darwin `system.defaults.dock.*` options?

### Investigation Results

Based on `docs/darwin-defaults-migration-analysis.md` from spec 002, the mapping is:

| Setting | Dotfiles Command | nix-darwin Option | Status |
|---------|-----------------|-------------------|--------|
| Disable recent apps | `disable_recent_apps_from_dock` | `show-recents = false` | ✅ Available |
| Show indicator lights | `show-process-indicators -bool true` | `show-process-indicators = true` | ✅ Available |
| Disable opening animations | `launchanim -bool false` | `launchanim = false` | ✅ Available |
| Remove auto-hiding delay | `autohide-delay -float 0` | `autohide-delay = 0.0` | ✅ Available |
| Remove hiding animation | `autohide-time-modifier -float 0` | `autohide-time-modifier = 0.0` | ✅ Available |
| Enable auto-hide | `autohide -bool true` | `autohide = true` | ✅ Available |
| Make hidden apps translucent | `showhidden -bool true` | `showhidden = true` | ✅ Available |
| Set minimize animation | `mineffect -string scale` | `mineffect = "scale"` | ✅ Available |
| Set dock size | `tilesize -integer 36` | `tilesize = 36` | ✅ Available |
| Minimize to app icon | `minimize-to-application -bool true` | `minimize-to-application = true` | ✅ Available |
| Speed up Mission Control | `expose-animation-duration -float 0.1` | `expose-animation-duration = 0.1` | ✅ Available |
| Don't group by app | `expose-group-by-app -bool false` | `expose-group-apps = false` | ✅ Available (different key) |
| Don't rearrange Spaces | `mru-spaces -bool false` | `mru-spaces = false` | ✅ Available |
| Enable highlight hover | `mouse-over-hilte-stack -bool true` | ❌ Not available | Requires activation script |
| Enable spring loading | `enable-spring-load-actions-on-all-items -bool true` | ❌ Not available | Requires activation script |

### Decision

**Use nix-darwin options for 13 settings, activation scripts for 2 settings**

**nix-darwin Configuration** (13 settings):

```nix
system.defaults.dock = {
  show-recents = false;                    # Disable recent apps
  show-process-indicators = true;          # Show indicator lights
  launchanim = false;                      # Disable opening animations
  autohide-delay = 0.0;                    # Remove auto-hiding delay
  autohide-time-modifier = 0.0;            # Remove hiding animation
  autohide = true;                         # Enable auto-hide
  showhidden = true;                       # Make hidden apps translucent
  mineffect = "scale";                     # Set minimize animation
  tilesize = 36;                           # Set dock size
  minimize-to-application = true;          # Minimize to app icon
  expose-animation-duration = 0.1;         # Speed up Mission Control
  expose-group-apps = false;               # Don't group by app (note: different key name)
  mru-spaces = false;                      # Don't rearrange Spaces
};
```

**Activation Script** (2 settings):

```bash
# Settings not available in nix-darwin options
defaults write com.apple.dock mouse-over-hilite-stack -bool true  # Note: corrected typo "hilte" → "hilite"
defaults write com.apple.dock enable-spring-load-actions-on-all-items -bool true
```

### Rationale

- Prefer nix-darwin declarative options for maintainability and type safety
- Use activation scripts only when nix-darwin doesn't expose the setting
- This approach aligns with constitution principle of "Declarative Configuration First"

### Alternatives Considered

1. **All activation scripts**: Rejected - unnecessarily imperative, loses type checking
1. **All nix-darwin**: Rejected - not possible, 2 settings unavailable
1. **CustomUserPreferences**: Rejected - activation scripts are simpler for 2 settings

______________________________________________________________________

## Decision 2: Application Path Verification

### Question

Do all application paths from dotfiles exist on target macOS system? Do any need adjustment?

### Investigation Results

**Dotfiles Configuration**:

```bash
declare -a dockItems=(
    '/Applications/Zen.app'                              # ✅ Third-party app
    '/Applications/Brave\ Browser.app'                   # ✅ Third-party app (note: backslash escaping)
    '/System/Applications/Mail.app'                      # ✅ System app
    '/System/Applications/Maps.app'                      # ✅ System app
    '/Applications/Bitwarden.app'                        # ✅ Third-party app
    '/Applications/Qobuz.app'                            # ✅ Third-party app
    'spacer'                                             # ✅ Special value
    '/Applications/Zed.app'                              # ✅ Third-party app
    '/Applications/Ghostty.app'                          # ✅ Third-party app
    '/Applications/Obsidian.app'                         # ✅ Third-party app
    '/Applications/UTM.app'                              # ✅ Third-party app
    'spacer'                                             # ✅ Special value
    '/System/Applications/System\ Settings.app'          # ✅ System app (note: backslash escaping)
    '/System/Applications/Utilities/Activity\ Monitor.app' # ✅ System app (note: backslash escaping)
    '/System/Applications/Utilities/Print\ Center.app'  # ⚠️ Verify name (might be "Printer Utility")
    'spacer'                                             # ✅ Special value
    "$HOME/Downloads"                                    # ✅ Folder (needs variable expansion)
);
```

**Path Categories**:

1. **System apps** (`/System/Applications/`): Always present on macOS
1. **Third-party apps** (`/Applications/`): Must be installed separately
1. **Folders**: Require variable expansion (`$HOME` → `/Users/charles`)

### Decision

**Use paths exactly as specified in dotfiles, with corrections:**

1. Remove backslash escaping (helper functions handle spaces)
1. Expand `$HOME` variable to actual user home directory
1. Document that applications must be installed before Dock configuration runs

**Corrected Paths**:

```nix
# Apps with spaces - no backslash needed
'/Applications/Brave Browser.app'
'/System/Applications/System Settings.app'
'/System/Applications/Utilities/Activity Monitor.app'
'/System/Applications/Utilities/Print Center.app'

# Folder - expand $HOME
'${config.users.primaryUser or "charles"}' + "/Downloads"
# Or simply: /Users/charles/Downloads
```

### Rationale

- Helper library functions (`mkDockAddApp`) already handle path escaping via `lib.escapeShellArg`
- Backslash escaping in dotfiles is for bash, not needed in Nix strings
- Variable expansion ensures configuration works regardless of username

### Alternatives Considered

1. **Keep backslash escaping**: Rejected - causes errors, helper lib handles escaping
1. **Check app existence before adding**: Rejected - adds complexity, dockutil handles gracefully
1. **Install apps as dependencies**: Out of scope - assumes apps already installed

______________________________________________________________________

## Decision 3: Helper Library Function Confirmation

### Question

Confirm all required helper functions exist in `modules/darwin/lib/mac.nix` and work correctly

### Investigation Results

**Source**: `modules/darwin/lib/mac.nix` (from spec 006)

**Required Functions**:

1. ✅ **`mkDockClear`**

   - **Signature**: `string` (no parameters)
   - **Output**: `${dockutil} --remove all --no-restart || true`
   - **Purpose**: Remove all existing Dock items
   - **Idempotency**: `|| true` ensures no failure if Dock already empty

1. ✅ **`mkDockAddApp`**

   - **Signature**: `{ path :: String, position :: Int? } -> String`
   - **Output**: Idempotent check + dockutil add command
   - **Idempotency**: Checks if app exists before adding (`dockutil --find`)
   - **Example**: `mkDockAddApp { path = "/Applications/Safari.app"; position = 1; }`

1. ✅ **`mkDockAddSpacer`**

   - **Signature**: `string` (no parameters)
   - **Output**: `${dockutil} --add "" --type spacer --section apps --no-restart`
   - **Purpose**: Add visual spacer between app groups
   - **Fixed**: Empty string uses `""` not `''` (spec 006 syntax fix)

1. ✅ **`mkDockAddSmallSpacer`**

   - **Signature**: `string` (no parameters)
   - **Output**: `${dockutil} --add "" --type small-spacer --section apps --no-restart`
   - **Purpose**: Add smaller visual spacer
   - **Note**: Not needed for this migration (dotfiles uses regular spacers)

1. ✅ **`mkDockAddFolder`**

   - **Signature**: `{ path :: String, view :: String?, display :: String?, sort :: String? } -> String`
   - **Output**: Idempotent check + dockutil add with folder options
   - **Idempotency**: Checks if folder exists before adding
   - **Example**: `mkDockAddFolder { path = "/Users/charles/Downloads"; view = "fan"; display = "stack"; }`

1. ✅ **`mkDockRestart`**

   - **Signature**: `string` (no parameters)
   - **Output**: `if pgrep -x Dock > /dev/null; then killall -KILL Dock; fi`
   - **Purpose**: Restart Dock to apply all changes
   - **Safety**: Checks if Dock is running before killing

### Decision

**Use all helper functions as designed, no modifications needed**

All required functions exist in `modules/darwin/lib/mac.nix` and were validated in spec 006 testing. Functions are:

- Idempotent (safe to rerun)
- Properly escaped (handle spaces in paths)
- Tested and working (spec 006 validation complete)

### Rationale

- Helper library (spec 006) was designed specifically for this use case
- Functions follow constitution requirement for activation script helpers
- No need to create custom functions or workarounds

### Alternatives Considered

1. **Direct dockutil commands**: Rejected - violates constitution (NON-NEGOTIABLE)
1. **Custom wrapper functions**: Rejected - unnecessary, helpers already exist
1. **Bash script extraction**: Rejected - simple enough for inline activation script

______________________________________________________________________

## Decision 4: Folder View Options

### Question

What are the valid options for `mkDockAddFolder` parameters (view, display, sort)?

### Investigation Results

**Source**: dockutil documentation and `modules/darwin/lib/mac.nix` implementation

**Valid Values**:

**`view` parameter** (How folder contents are displayed):

- `"fan"` - Fan layout (files spread out)
- `"grid"` - Grid layout (files in grid)
- `"list"` - List layout (files in list)
- `"automatic"` - Let system choose

**`display` parameter** (How Dock shows the folder):

- `"folder"` - Show as folder icon
- `"stack"` - Show as stack of files

**`sort` parameter** (How items are sorted):

- `"name"` - Sort alphabetically by name
- `"dateadded"` - Sort by date added
- `"datemodified"` - Sort by date modified
- `"datecreated"` - Sort by date created
- `"kind"` - Sort by file type

### Decision

**Downloads folder configuration:**

```nix
mkDockAddFolder {
  path = "/Users/charles/Downloads";
  view = "fan";
  display = "stack";
  sort = "dateadded";
}
```

### Rationale

- **Fan view**: Most visual representation for recent downloads
- **Stack display**: Shows folder as stack (common for Downloads)
- **Sort by dateadded**: Most recent downloads appear first (typical user expectation)

This configuration matches typical macOS user behavior for the Downloads folder.

### Alternatives Considered

1. **Grid view**: Rejected - less visual than fan for folders
1. **Folder display**: Rejected - stack is more common for Downloads
1. **Sort by name**: Rejected - date added is more useful for Downloads

______________________________________________________________________

## Additional Findings

### Finding 1: Typo in Original Dotfiles

**Issue**: Original dotfiles has `mouse-over-hilte-stack` (typo)\
**Correction**: Should be `mouse-over-hilite-stack` (correct spelling)\
**Impact**: Will use corrected spelling in activation script

### Finding 2: Position Parameter Behavior

**Discovery**: Helper function `mkDockAddApp` accepts optional `position` parameter\
**Usage**: Can specify explicit position (1, 2, 3...) or default to "end"\
**Strategy**: Specify explicit positions for all apps to ensure correct order

### Finding 3: Dock Restart Requirement

**Discovery**: All dockutil commands use `--no-restart` flag\
**Reason**: Allows batch operations without multiple Dock restarts\
**Solution**: Call `mkDockRestart` once at the end to apply all changes

______________________________________________________________________

## Research Summary

### Resolved Unknowns

1. ✅ **nix-darwin mapping**: 13 settings via nix-darwin, 2 via activation scripts
1. ✅ **Application paths**: Use as-is, remove backslash escaping, expand $HOME
1. ✅ **Helper functions**: All required functions exist and work correctly
1. ✅ **Folder options**: Fan view, stack display, sort by dateadded

### Key Insights

1. **Prefer nix-darwin options**: More declarative, type-safe, easier to maintain
1. **Helper library ready**: Spec 006 provides all necessary primitives
1. **Idempotency built-in**: All helper functions check before modifying
1. **Order matters**: Use explicit positions to ensure correct Dock layout

### No Blockers

All technical unknowns have been resolved. Implementation can proceed with:

- 13 Dock settings via `system.defaults.dock.*`
- 2 Dock settings via activation script with `defaults write`
- 17 Dock items via helper library functions
- 0 additional dependencies or functions needed

______________________________________________________________________

## References

- **Feature Spec**: [spec.md](./spec.md)
- **Implementation Plan**: [plan.md](./plan.md)
- **Helper Library**: `modules/darwin/lib/mac.nix` (spec 006)
- **Migration Analysis**: `docs/darwin-defaults-migration-analysis.md` (spec 002)
- **Dotfiles Source**: `~/project/dotfiles/scripts/sh/darwin/system.sh`
- **dockutil Documentation**: [GitHub](https://github.com/kcrawford/dockutil)
