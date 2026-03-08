# Implementation Plan: Keyboard Configuration Restructure

**Branch**: `044-keyboard-config-restructure` | **Date**: 2026-02-07 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/044-keyboard-config-restructure/spec.md`

## Summary

Restructure the user keyboard configuration from a flat `keyboardLayout` field to a grouped `keyboard` namespace containing `layout` (list of layout names) and `macStyleMappings` (boolean, default true). The `macStyleMappings` setting makes the currently hardcoded Super/Ctrl key swap on Linux opt-out. All 9 production files referencing `keyboardLayout` are updated to use the new path. No backward compatibility shims per constitution.

## Technical Context

**Language/Version**: Nix (flakes, 2.19+)\
**Primary Dependencies**: Home Manager (standalone), nix-darwin, NixOS modules\
**Storage**: N/A (declarative configuration files)\
**Testing**: `nix flake check`, `just build <user> <host>`\
**Target Platform**: macOS (Darwin), NixOS (GNOME, Niri)\
**Project Type**: Nix configuration repository\
**Performance Goals**: N/A (build-time configuration)\
**Constraints**: Modules < 200 lines, lib.mkDefault for overridability\
**Scale/Scope**: 9 files modified, 1 user config migrated, 3 templates updated

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Declarative Configuration First | PASS | All changes are declarative Nix expressions |
| II. Modularity and Reusability | PASS | Keyboard config is self-contained submodule, < 200 lines per file |
| III. Documentation-Driven Development | PASS | Schema has descriptions, examples; spec and plan documented |
| IV. Purity and Reproducibility | PASS | No network access, no impure operations |
| V. Testing and Validation | PASS | `nix flake check` + `just build` verification |
| VI. Cross-Platform Compatibility | PASS | Darwin ignores macStyleMappings; Linux/GNOME/Niri consume it |
| Context Validation | PASS | Existing context guards preserved; no new cross-context issues |
| No Backward Compatibility | PASS | `keyboardLayout` removed entirely, no shims |
| Module Size < 200 lines | PASS | All modified files remain well under 200 lines |
| App-Centric Organization | PASS | Keyboard settings remain in their existing settings files |

**Post-design re-check**: All gates still pass. No violations.

## Project Structure

### Documentation (this feature)

```text
specs/044-keyboard-config-restructure/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0 research decisions
├── data-model.md        # Entity model for keyboard config
├── quickstart.md        # Usage examples and verification
├── contracts/
│   └── keyboard-schema.nix  # Schema contract
└── checklists/
    └── requirements.md  # Quality checklist
```

### Source Code (files to modify)

```text
user/
├── shared/
│   ├── lib/
│   │   └── user-schema.nix              # Replace keyboardLayout with keyboard submodule
│   └── template/
│       ├── developer.nix                # Migrate to keyboard block
│       ├── basic-english.nix            # Migrate to keyboard block
│       └── basic-french.nix             # Migrate to keyboard block
├── cdrokar/
│   └── default.nix                      # Migrate to keyboard block

system/
├── darwin/
│   └── settings/system/
│       └── keyboard.nix                 # Read from keyboard.layout
├── shared/
│   └── family/
│       ├── linux/settings/system/
│       │   └── keyboard.nix             # Read keyboard.layout + conditional macStyleMappings
│       ├── gnome/settings/user/
│       │   └── keyboard.nix             # Read keyboard.layout + conditional macStyleMappings
│       └── niri/settings/user/
│           └── keyboard.nix             # Read from keyboard.layout
```

**Structure Decision**: No new files created. All changes are modifications to existing files within the established directory structure.

## Complexity Tracking

No constitution violations. No complexity tracking needed.
