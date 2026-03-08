# Implementation Plan: GNOME Dock Module

**Branch**: `024-gnome-dock-module` | **Date**: 2025-12-19 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/024-gnome-dock-module/spec.md`
**Parent Feature**: 023-user-dock-config (Darwin implementation complete)

## Summary

Extend the user dock configuration feature to GNOME desktop environments. The implementation resolves application names to `.desktop` file references and sets GNOME Shell favorites via dconf. Uses the existing shared parsing library from Feature 023.

## Technical Context

**Language/Version**: Nix 2.19+ with flakes enabled
**Primary Dependencies**: Home Manager, dconf/gsettings, glib
**Storage**: N/A (declarative Nix configuration files)
**Testing**: `nix flake check`, manual activation testing on GNOME
**Target Platform**: NixOS with GNOME desktop, or any Linux with Home Manager + GNOME
**Project Type**: Nix configuration modules
**Performance Goals**: Configuration applies within activation phase
**Constraints**: Must use dconf for GNOME settings; .desktop files for app references
**Scale/Scope**: Shared family module usable by any GNOME host

## Constitution Check

*GATE: Must pass before implementation.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Declarative Configuration First | PASS | All config via Nix expressions + dconf |
| II. Modularity and Reusability | PASS | Shared family module, reuses parsing lib |
| III. Documentation-Driven | PASS | Spec complete with scenarios |
| IV. Purity and Reproducibility | PASS | Same config → same favorites |
| V. Testing and Validation | PASS | `nix flake check` + manual testing |
| VI. Cross-Platform Compatibility | PASS | GNOME-specific in family/, reuses shared lib |
| Module Size \<200 lines | PASS | Two small modules |
| App-Centric Organization | PASS | Dock module is self-contained |

**Gate Status**: PASSED

## Project Structure

### Documentation (this feature)

```text
specs/024-gnome-dock-module/
├── spec.md              # Feature specification (complete)
├── plan.md              # This file
├── research.md          # Research findings (using 023 research)
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # N/A (no API contracts for Nix modules)
└── tasks.md             # Phase 2 output
```

### Source Code (repository root)

```text
system/
├── shared/
│   ├── lib/
│   │   └── dock.nix          # EXISTING: Shared parsing library (from 023)
│   └── family/
│       └── gnome/
│           ├── lib/
│           │   └── dock.nix  # NEW: GNOME-specific resolution
│           └── settings/
│               └── dock.nix  # NEW: GNOME dock activation via dconf
```

**Structure Decision**: Follows the family architecture pattern. GNOME-specific dock logic goes in the `gnome` family directory, reusing the shared parsing library.

## Complexity Tracking

No constitution violations. Implementation follows established patterns.

## Design Decisions

### D1: Desktop File Resolution

**Decision**: Search XDG directories for .desktop files with partial name matching.
**Rationale**: Standard freedesktop approach; covers Nix-installed, system, and Flatpak apps.

Search order:

1. `~/.local/share/applications/` (user apps, including our trash.desktop)
1. `/run/current-system/sw/share/applications/` (NixOS system apps)
1. `/usr/share/applications/` (traditional Linux apps)

### D2: Partial Name Matching

**Decision**: Match app name as prefix or substring of .desktop filename.
**Rationale**: Users specify "firefox", system has "org.mozilla.firefox.desktop".

Algorithm:

1. Try exact: `firefox.desktop`
1. Try with org prefix: `org.*.firefox.desktop` pattern
1. Try contains: `*firefox*.desktop`

### D3: dconf vs gsettings

**Decision**: Use Home Manager's `dconf.settings` option.
**Rationale**: Declarative, integrates with Home Manager, persists properly.

```nix
dconf.settings = {
  "org/gnome/shell" = {
    favorite-apps = [ "firefox.desktop" ... ];
  };
};
```

### D4: Trash Desktop File

**Decision**: Create trash.desktop via `home.file` when `<trash>` in docked array.
**Rationale**: GNOME doesn't have a built-in trash .desktop file.

```ini
[Desktop Entry]
Type=Application
Name=Trash
Icon=user-trash-full
Exec=nautilus trash://
```

### D5: Unsupported Features

**Decision**: Silently ignore separators and folders.
**Rationale**: Cross-platform compatibility; same config works everywhere.

## Implementation Phases

### Phase 1: GNOME Library

1. Create `system/shared/family/gnome/lib/dock.nix`
1. Implement `resolveDesktopFile` function for .desktop lookup
1. Import shared parsing library
1. Filter out separators, folders, unknown system items

### Phase 2: GNOME Settings Module

1. Create `system/shared/family/gnome/settings/dock.nix`
1. Read `user.docked` from config
1. Resolve app names to .desktop files
1. Generate dconf settings for favorite-apps
1. Create trash.desktop if `<trash>` present

### Phase 3: Testing

1. Test on NixOS with GNOME
1. Verify favorites appear correctly
1. Verify trash.desktop creation
1. Verify unsupported items silently ignored
