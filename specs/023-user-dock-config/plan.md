# Implementation Plan: User Dock Configuration

**Branch**: `023-user-dock-config` | **Date**: 2025-12-18 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/023-user-dock-config/spec.md`

## Summary

Enable users to define dock layout (applications, folders, separators, system items) in their user configuration using a platform-agnostic syntax. The system resolves names to platform-specific paths at activation time. Darwin uses dockutil; GNOME uses gsettings with .desktop files.

## Technical Context

**Language/Version**: Nix 2.19+ with flakes enabled
**Primary Dependencies**: nix-darwin, Home Manager, dockutil (darwin), glib (GNOME gsettings)
**Storage**: N/A (declarative Nix configuration files)
**Testing**: `nix flake check`, manual activation testing
**Target Platform**: Darwin (primary), GNOME/Linux (secondary)
**Project Type**: Nix configuration modules
**Performance Goals**: Dock configuration completes within activation phase (\<5s)
**Constraints**: Must run after application installation; silent failure for missing items
**Scale/Scope**: 3 users, 2+ hosts, ~50 applications

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Declarative Configuration First | ✅ PASS | All dock config via Nix expressions |
| II. Modularity and Reusability | ✅ PASS | User config is pure data; dock module handles resolution |
| III. Documentation-Driven | ✅ PASS | Spec complete with syntax rules and examples |
| IV. Purity and Reproducibility | ✅ PASS | Same config → same dock layout |
| V. Testing and Validation | ✅ PASS | `nix flake check` + activation testing |
| VI. Cross-Platform Compatibility | ✅ PASS | Platform-agnostic syntax; platform-specific modules |
| App-Centric Organization | ✅ PASS | Dock module is self-contained |
| Module Size \<200 lines | ✅ PASS | Will refactor if exceeded |
| Pure Data Pattern | ✅ PASS | `user.docked` is pure data array |

**Gate Status**: PASSED - Proceeding to design phase.

## Project Structure

### Documentation (this feature)

```text
specs/023-user-dock-config/
├── spec.md              # Feature specification (complete)
├── plan.md              # This file
├── research.md          # Research findings (complete)
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # N/A (no API contracts for Nix modules)
└── tasks.md             # Phase 2 output
```

### Source Code (repository root)

```text
user/
└── {username}/
    └── default.nix           # Add optional `docked` field

system/
├── darwin/
│   ├── lib/
│   │   └── dock.nix          # MODIFY: Add resolution functions
│   └── settings/
│       └── dock.nix          # MODIFY: Read user.docked, generate activation
│
├── shared/
│   ├── lib/
│   │   └── dock.nix          # NEW: Cross-platform dock utilities (parsing)
│   └── family/
│       └── gnome/
│           ├── lib/
│           │   └── dock.nix  # NEW: GNOME dock resolution
│           └── settings/
│               └── dock.nix  # NEW: GNOME dock activation via dconf
```

**Structure Decision**: Follows existing hierarchical pattern with platform-specific implementations inheriting from shared utilities. No new directories needed beyond gnome/lib/ and gnome/settings/.

## Complexity Tracking

No constitution violations. Implementation follows established patterns.

## Design Decisions

### D1: Entry Type Detection

**Decision**: Use string pattern matching on dock entries.
**Rationale**: Simple, no metadata needed. Syntax is unambiguous.

| Pattern | Detection | Type |
|---------|-----------|------|
| `<...>` | Regex `^<.+>$` | System item |
| `/...` | Starts with `/` | Folder |
| `\|` or `\|\|` | Exact match | Separator |
| Other | Default | Application name |

### D2: Application Resolution (Darwin)

**Decision**: Search known filesystem locations.
**Rationale**: No external metadata required; covers system and user apps.

```nix
searchPaths = [
  "/Applications"
  "/System/Applications"
  "/System/Applications/Utilities"
  "~/Applications"
];
```

### D3: Application Resolution (GNOME)

**Decision**: Search for .desktop files in XDG locations.
**Rationale**: Standard freedesktop approach; covers Nix, system, and Flatpak apps.

```nix
desktopDirs = [
  "~/.local/share/applications"
  "/usr/share/applications"
  "/run/current-system/sw/share/applications"  # NixOS
];
```

### D4: Folder Resolution

**Decision**: Fallback resolution (user home first, then absolute).
**Rationale**: Covers both user folders (`/Downloads`) and system paths (`/Volumes/Backup`).

### D5: Trash Handling

**Decision**: Platform-specific behavior.

- Darwin: `<trash>` is a no-op (macOS manages automatically)
- GNOME: Create `trash.desktop` file and add to favorites

**Rationale**: Darwin cannot control trash position; GNOME requires explicit desktop file.

### D6: Module Integration Point

**Decision**: Read `user.docked` in platform dock settings module.
**Rationale**: Follows existing pattern where settings modules consume user config.

## Implementation Phases

### Phase 1: Darwin Refactor

1. Add `docked` field to user options (optional array of strings)
1. Create `system/shared/lib/dock.nix` with parsing utilities
1. Extend `system/darwin/lib/dock.nix` with app/folder resolution
1. Modify `system/darwin/settings/dock.nix` to read `user.docked`
1. Remove hardcoded app list from dock.nix

### Phase 2: GNOME Implementation

1. Create `system/shared/family/gnome/lib/dock.nix` with .desktop resolution
1. Create `system/shared/family/gnome/settings/dock.nix` with gsettings activation
1. Handle trash.desktop creation when `<trash>` specified

### Phase 3: Validation & Testing

1. Test empty `docked` array (clears dock)
1. Test missing applications (silent skip)
1. Test folder resolution (user and absolute paths)
1. Test separators (standard and thick)
1. Test system items on both platforms
