# Research: User Wallpaper Configuration

**Feature**: 033-user-wallpaper-config\
**Date**: 2025-12-30\
**Research Phase**: Phase 0 - Technical Foundation

## Overview

This document consolidates research findings for implementing platform-agnostic wallpaper configuration on Darwin (macOS) and GNOME desktop environments. Research focused on three key areas:

1. **Darwin (macOS) wallpaper APIs** - Command-line methods for setting wallpapers
1. **GNOME wallpaper configuration** - dconf/gsettings paths and patterns
1. **Nix file path validation** - Best practices for handling user-provided file paths

______________________________________________________________________

## 1. Darwin (macOS) Wallpaper Configuration

### Decision: Use `desktoppr` for Per-Monitor Support (US3), `osascript` for Single Wallpaper (US1-US2)

**Rationale:**

- **US1-US2** (single wallpaper): Use `osascript` - built-in, no dependencies, sufficient for same wallpaper on all monitors
- **US3** (per-monitor): Use `desktoppr` - native multi-monitor support, clean API for monitor-specific wallpapers
- Trade-off: Accept Homebrew dependency for enhanced multi-monitor functionality
- Constitutional compliance: Homebrew integration already established pattern (see aerospace, cursor apps)

**Implementation Strategy:**

- US1-US2: osascript for "tell every desktop" (same wallpaper)
- US3: Detect if `user.wallpapers` configured, switch to desktoppr
- Install desktoppr via Homebrew when `user.wallpapers` is used
- Fallback behavior: If user has both `user.wallpaper` and `user.wallpapers`, per-monitor config takes precedence

### Implementation Approach

**Command syntax:**

```bash
osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"$WALLPAPER_PATH\""
```

**Key details:**

- **Multiple monitor support**: Use "tell every desktop" to apply to all displays
- **Path requirements**: Must use absolute paths (no tilde expansion in AppleScript)
- **File formats supported**: JPEG, PNG, HEIC, TIFF, GIF
- **Permission requirements**: Requires TCC approval for AppleEvents (one-time user prompt)
- **User context**: Must run as user (not root) - perfect for Home Manager activation

### Path Handling

**Tilde expansion:**

- AppleScript's `POSIX file` does NOT support `~`
- Solution: Use `${config.home.homeDirectory}` in activation script
- Example: `/Users/username/Pictures/wallpaper.jpg`

**Shell expansion pattern:**

```nix
home.activation.setWallpaper = lib.hm.dagEntryAfter ["writeBoundary"] ''
  WALLPAPER="${config.user.wallpaper}"
  if [ -f "$WALLPAPER" ]; then
    /usr/bin/osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"$WALLPAPER\""
  fi
'';
```

### Edge Cases

1. **Spaces in paths**: Handled by bash double quotes (`"$WALLPAPER"`)
1. **Missing files**: Check with `[ -f "$WALLPAPER" ]` before setting
1. **TCC permissions**: First run prompts user for "Terminal wants to control System Events"
1. **Dynamic wallpapers**: HEIC format supports time-of-day changing wallpapers

______________________________________________________________________

## 2. GNOME Wallpaper Configuration

### Decision: Use `nitrogen` for Per-Monitor Support (US3), `dconf.settings` for Single Wallpaper (US1-US2)

**Rationale:**

- **US1-US2** (single wallpaper): Use `dconf.settings` - declarative, integrated with Home Manager, native GNOME
- **US3** (per-monitor): Use `nitrogen` - lightweight, multi-monitor support, works with any window manager
- Alternative considered: `hydrapaper` (GUI-only, less scriptable), `feh` (X11 only, not Wayland)
- Trade-off: Accept additional package dependency for multi-monitor functionality
- Constitutional compliance: Package dependencies are standard pattern in nix-config

**Implementation Strategy:**

- US1-US2: dconf.settings for single wallpaper (both picture-uri fields)
- US3: Install nitrogen package, create systemd user service to run on login
- Service runs nitrogen with per-monitor arguments
- Nitrogen persists settings, works across GNOME/non-GNOME desktops
- Fallback behavior: If user has both `user.wallpaper` and `user.wallpapers`, per-monitor config takes precedence

### Implementation Approach

**dconf path:**

```nix
dconf.settings = {
  "org/gnome/desktop/background" = {
    picture-uri = "file:///home/username/Pictures/wallpaper.jpg";
    picture-uri-dark = "file:///home/username/Pictures/wallpaper.jpg";
    picture-options = "zoom";  # or "scaled", "centered", "spanned"
  };
};
```

**Key details:**

- **File URI format**: Must use `file:///` (three slashes) for local files
- **Dark mode support**: GNOME 42+ switches between `picture-uri` and `picture-uri-dark` automatically
- **Multiple monitors**: `picture-options = "spanned"` spans single image across all displays
- **File formats supported**: JPEG, PNG, SVG, TGA, BMP, GIF
- **Permission requirements**: User-level only (no root/sudo needed), requires active D-Bus session

### Path Handling

**Tilde expansion:**

- `gsettings` does NOT expand `~` in file paths
- Solution: Use `${config.home.homeDirectory}` in Nix expression
- Example: `"file://${config.home.homeDirectory}/Pictures/wallpaper.jpg"`

**Nix expression pattern:**

```nix
let
  wallpaperPath = config.user.wallpaper;
  mkFileUri = path: "file://${path}";
in {
  dconf.settings."org/gnome/desktop/background" = {
    picture-uri = mkFileUri wallpaperPath;
    picture-uri-dark = mkFileUri wallpaperPath;
  };
}
```

### Edge Cases

1. **File URI format**: Must include `file:///` prefix (three slashes for local files)
1. **Missing files**: GNOME falls back to default wallpaper silently (no error)
1. **Dark mode compatibility**: Older GNOME versions ignore `picture-uri-dark` (safe to set both)
1. **Lock screen**: Separate path at `org/gnome/desktop/screensaver/picture-uri` (optional)
1. **Session timing**: Changes apply immediately (no logout required)

______________________________________________________________________

## 3. Nix File Path Validation

### Decision: Runtime Validation with Warnings (No Build Failures)

**Rationale:**

- User-provided file paths are outside Nix store (impure)
- Failing build on missing wallpaper is too strict (wallpaper is cosmetic)
- Warnings inform user of issues without blocking system activation
- Runtime validation (`[ -f "$path" ]`) handles file existence

**Alternative Considered:**

- Build-time validation with `builtins.pathExists`
- **Rejected**: Doesn't work for paths that don't exist at build time
- **Partial use**: Can validate during evaluation to provide early feedback

### Validation Strategy

**Three-tier validation:**

1. **Build-time warnings** (`config.warnings`):

   - Check if path is set but file doesn't exist
   - Check if file extension is supported
   - Non-blocking (build continues, user sees warnings)

1. **Runtime existence check** (activation script):

   - Use `[ -f "$path" ]` before attempting to set wallpaper
   - Gracefully skip if missing (don't fail activation)
   - Log warning to stderr

1. **Format validation** (file extension):

   - Use `lib.hasSuffix` to check extensions
   - Support: `.jpg`, `.jpeg`, `.png`, `.heic`, `.webp`
   - Warn if unsupported extension detected

### Implementation Patterns

**File existence check:**

```nix
let
  wallpaperPath = config.user.wallpaper or null;
  wallpaperExists = wallpaperPath != null && builtins.pathExists wallpaperPath;
in {
  # Build-time warning
  warnings = lib.optional (wallpaperPath != null && !wallpaperExists)
    "Wallpaper file not found: ${wallpaperPath}";
  
  # Runtime validation
  home.activation.setWallpaper = ''
    if [ -f "$WALLPAPER" ]; then
      # Set wallpaper
    else
      echo "Warning: Wallpaper not found: $WALLPAPER" >&2
    fi
  '';
}
```

**File extension validation:**

```nix
let
  validExts = [".jpg" ".jpeg" ".png" ".heic" ".webp"];
  hasValidExt = wallpaperPath != null 
    && lib.any (ext: lib.hasSuffix ext (lib.toLower wallpaperPath)) validExts;
in {
  warnings = lib.optional (wallpaperPath != null && !hasValidExt)
    "Wallpaper has unsupported extension. Supported: ${lib.concatStringsSep ", " validExts}";
}
```

**Tilde expansion helper:**

```nix
expandPath = path:
  if lib.hasPrefix "~/" path
  then "${config.home.homeDirectory}/${lib.removePrefix "~/" path}"
  else path;
  
wallpaperPath = if cfg.path != null then expandPath cfg.path else null;
```

### Edge Cases

1. **Paths with spaces**: Properly quoted in shell context (`"$VAR"`)
1. **Relative paths**: Resolved relative to home directory if starting with `~/`
1. **Absolute paths**: Used as-is (no transformation)
1. **Missing file**: Warning logged, wallpaper setting skipped (no build failure)
1. **Invalid format**: Warning logged, wallpaper setting attempted anyway (let platform handle it)

______________________________________________________________________

## Key Decisions Summary

### Darwin Implementation

| Aspect | Decision | Rationale |
|--------|----------|-----------|
| **API (US1-US2)** | osascript (AppleScript) | Built-in, no dependencies, same wallpaper all displays |
| **API (US3)** | desktoppr (Homebrew) | Native per-monitor support, clean API |
| **Multi-monitor (single)** | "tell every desktop" | Applies same wallpaper to all displays |
| **Multi-monitor (per-monitor)** | `desktoppr <monitor> <path>` | Set different wallpaper per monitor index |
| **Validation** | Runtime with `[ -f ]` | Files outside Nix store, validate at activation time |
| **Path format** | Absolute paths via `$HOME` | Both tools require absolute paths, no tilde support |
| **Permissions** | TCC approval (osascript) | One-time approval, desktoppr avoids TCC |
| **Package dependency** | desktoppr via Homebrew | Only when `user.wallpapers` configured |

### GNOME Implementation

| Aspect | Decision | Rationale |
|--------|----------|-----------|
| **API (US1-US2)** | dconf.settings | Declarative, integrated with Home Manager, native GNOME |
| **API (US3)** | nitrogen (package) | Lightweight, multi-monitor support, works on Wayland |
| **Dark mode** | Set both picture-uri fields | Ensures wallpaper applies in light and dark modes (single wallpaper only) |
| **Multi-monitor (single)** | picture-options="zoom" | Maintains aspect ratio across displays |
| **Multi-monitor (per-monitor)** | nitrogen systemd service | Run on login, set per-monitor wallpapers |
| **Validation** | Build warnings + runtime check | Non-blocking validation with user feedback |
| **Path format (dconf)** | file:// URI with absolute path | GNOME requires URI scheme with three slashes |
| **Path format (nitrogen)** | Absolute paths | Nitrogen accepts standard file paths |
| **Permissions** | User-level (both) | No special permissions needed |
| **Package dependency** | nitrogen | Only when `user.wallpapers` configured |

### File Validation

| Aspect | Decision | Rationale |
|--------|----------|-----------|
| **Existence** | Runtime check, warn if missing | Don't fail build for cosmetic feature |
| **Format** | Extension check with warnings | Inform user of likely issues without blocking |
| **Tilde expansion** | Manual with `config.home.homeDirectory` | Nix/bash don't auto-expand `~` in all contexts |
| **Error handling** | Graceful degradation | Skip wallpaper setting if invalid, continue activation |
| **Build-time** | Use `builtins.pathExists` for early feedback | Helps catch issues during build when possible |

______________________________________________________________________

## Implementation Modules

Based on research findings, implementation will create:

1. **system/darwin/settings/wallpaper.nix**

   - Home Manager activation script using osascript
   - Runtime file existence validation
   - Applies to all monitors via "tell every desktop"

1. **system/shared/family/gnome/settings/wallpaper.nix**

   - dconf.settings configuration
   - Sets both picture-uri and picture-uri-dark
   - Build-time warnings for invalid paths

1. **Optional: user/shared/lib/wallpaper-helpers.nix** (if reusable functions needed)

   - Path expansion (tilde to absolute)
   - Extension validation
   - URI formatting for GNOME

______________________________________________________________________

## Open Questions (Resolved)

### Q1: Should we fail the build if wallpaper is invalid?

**Answer**: No. Use warnings and graceful degradation. Wallpaper is cosmetic; missing file shouldn't block system activation.

### Q2: How to handle per-monitor wallpapers (P3)?

**Answer**: Defer to P3. For P1, same wallpaper on all monitors is sufficient. Consider `desktoppr` for P3 darwin implementation.

### Q3: Should we support Nix store wallpapers (bundled in config)?

**Answer**: Not in P1. Users provide file paths to existing wallpapers. Could add in P2 via `home.file` symlinking.

### Q4: What about lock screen wallpapers?

**Answer**: Optional enhancement. GNOME has separate `org/gnome/desktop/screensaver/picture-uri`. Darwin uses same wallpaper for lock screen automatically.

______________________________________________________________________

## Research Sources

- macOS osascript documentation and AppleScript guides
- GNOME dconf/gsettings documentation
- Home Manager manual and source code (files.nix, dconf.nix, activation scripts)
- Nixpkgs lib functions (lib.hasSuffix, lib.warn, etc.)
- Existing codebase patterns (dock.nix, git-repos.nix, secrets.nix)

## Next Steps (Phase 1 - Design)

1. Create data-model.md defining wallpaper configuration structure
1. Generate contracts/ with user configuration schema
1. Write quickstart.md with usage examples
1. Update agent context with new technologies/patterns
1. Re-evaluate Constitution Check with concrete design
