# Implementation Plan: User Locale Configuration

**Branch**: `018-user-locale-config` | **Date**: 2025-11-15 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/018-user-locale-config/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Add user locale configuration fields (`languages`, `keyboardLayout`, `timezone`, `locale`) to user configurations, enabling platform-agnostic declaration of localization preferences. First implementation targets darwin platform, consuming these configurations to set macOS system language, keyboard layouts, timezone, and regional settings. Platform-agnostic keyboard layout names are translated to platform-specific identifiers via a translation layer in the darwin platform library.

## Technical Context

**Language/Version**: Nix 2.19+ with flakes enabled\
**Primary Dependencies**: nix-darwin, Home Manager, nixpkgs\
**Storage**: Declarative Nix configuration files (no persistent storage)\
**Testing**: `nix flake check`, `nix build`, darwin system activation verification\
**Target Platform**: macOS (darwin) via nix-darwin for first implementation
**Project Type**: Configuration management (Nix expressions)\
**Performance Goals**: Build time \<5 seconds for locale configuration changes, activation time \<10 seconds\
**Constraints**:

- Module size \<200 lines per constitutional requirement
- All locale fields must be optional (backward compatibility)
- Platform-agnostic keyboard layout naming requires translation layer
- Must maintain multi-user isolation
  **Scale/Scope**:
- 3 users (cdrokar, cdrolet, cdrixus)
- 1 platform (darwin) in first implementation
- 4 user configuration fields (languages, keyboardLayout, timezone, locale)
- Platform-agnostic keyboard layout registry (initial set: us, canadian-french, dvorak, colemak, etc.)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Initial Check (Before Phase 0)

✅ **I. Declarative Configuration First**: All locale settings declared in Nix expressions
✅ **II. Modularity and Reusability**: User config fields reusable across profiles, platform settings consume via modules
✅ **III. Documentation-Driven Development**: Module documentation required, user guide in docs/
✅ **IV. Purity and Reproducibility**: All settings deterministic, no network access during build
✅ **V. Testing and Validation**: Verify via `nix flake check`, build validation, activation testing
✅ **VI. Cross-Platform Compatibility**: Platform-agnostic keyboard layout naming, darwin implementation isolated

✅ **Flakes as Entry Point**: No changes to flake structure required
✅ **Home Manager Integration**: User locale configs consumed by Home Manager
✅ **Directory Structure Standard**: Following canonical structure
✅ **Specification Management**: Feature spec complete and approved
✅ **Code Organization**: Hierarchical structure, module size \<200 lines
✅ **Configuration Module Organization**: Topic-based, size limit enforced, lib.mkDefault usage
✅ **Helper Libraries**: Keyboard layout translation layer planned
✅ **Pre-Deployment Checks**: Full validation strategy defined
✅ **Performance and Resource Constraints**: Minimal closure size impact
✅ **Security Requirements**: No secrets involved

### Post-Design Check (After Phase 1)

✅ **Module Size Compliance**:

- `locale.nix`: Estimated ~150-180 lines (within 200-line limit)
- `keyboard-layout-translation.nix`: ~30 lines (well under limit)
- Can split if locale.nix exceeds 200 lines during implementation

✅ **Documentation Complete**:

- `research.md`: Technical decisions and nix-darwin module research (complete)
- `data-model.md`: Entity definitions and data flow (complete)
- `contracts/*.nix`: Type schemas for user config and registry (complete)
- `quickstart.md`: Developer implementation guide (complete)
- User documentation planned in `docs/features/018-user-locale-config.md`

✅ **Platform-Agnostic Design Verified**:

- User config uses platform-agnostic keyboard layout names ✓
- Translation layer isolates platform-specific identifiers ✓
- Darwin settings in `platform/darwin/settings/` ✓
- Future NixOS support architecture validated ✓

✅ **Helper Library Design**:

- `keyboard-layout-translation.nix` provides pure function (layout name → layout object)
- Registry structure supports multiple platforms
- Clear separation: registry (data) vs translation logic (function)
- Follows constitution: shared lib for cross-platform, platform lib for platform-specific

✅ **Backward Compatibility**:

- All locale fields optional (null by default)
- Existing user configs without locale fields continue to work
- Platform defaults used when fields not specified
- No breaking changes to existing configurations

✅ **Multi-User Isolation**:

- User config fields are per-user
- Darwin settings consume per-user userContext
- No global state that could interfere between users
- CustomUserPreferences writes to user's ~/Library/Preferences/

✅ **Testing Strategy**:

- Build-time: nix flake check, type validation, keyboard layout name validation
- Activation-time: just build, darwin-rebuild switch
- Runtime: defaults read verification commands
- Multi-user: build configs for all users, verify isolation

### Design Decisions Validated

✅ **Single locale.nix module**: Estimated size within limits, can split if needed
✅ **Translation layer architecture**: Enables future cross-platform support
✅ **Optional fields with defaults**: Ensures backward compatibility
✅ **userContext passing**: Follows existing pattern in codebase
✅ **lib.mkDefault usage**: All settings user-overridable per constitution

### Violations Requiring Justification

**None** - This feature fully complies with all constitutional requirements.

Post-design review confirms:

- All artifacts created meet documentation standards
- Module organization follows constitutional patterns
- Platform-agnostic design validated through translation layer
- No additional violations or concerns identified

## Project Structure

### Documentation (this feature)

```text
specs/018-user-locale-config/
├── spec.md              # Feature specification (completed)
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
│   └── locale-config-schema.nix  # Nix module type definitions
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
user/
├── cdrokar/
│   └── default.nix      # Add optional locale fields: languages, keyboardLayout, timezone, locale
├── cdrolet/
│   └── default.nix      # Add optional locale fields
├── cdrixus/
│   └── default.nix      # Add optional locale fields
└── shared/
    └── lib/
        └── home-manager.nix  # May need user config type definitions

platform/darwin/
├── lib/
│   ├── darwin.nix       # May need to pass locale configs to settings
│   └── keyboard-layout-translation.nix  # NEW: Platform-agnostic to darwin-specific mapping
├── settings/
│   ├── default.nix      # Import locale settings modules
│   ├── language.nix     # NEW: System language configuration from user.languages
│   ├── keyboard.nix     # NEW: Keyboard layout configuration from user.keyboardLayout
│   ├── timezone.nix     # NEW: Timezone configuration from user.timezone
│   └── regional.nix     # NEW: Regional settings from user.locale
└── profiles/
    ├── home-macmini-m4/
    │   └── default.nix  # No changes (consumes user configs automatically)
    └── work/
        └── default.nix  # No changes

docs/
└── features/
    └── 018-user-locale-config.md  # NEW: User guide for locale configuration
```

**Structure Decision**: Using existing Nix configuration structure. New modules follow constitutional pattern: user config fields in `user/{username}/default.nix`, darwin platform settings in `platform/darwin/settings/` (one module per locale aspect or consolidated if \<200 lines), keyboard layout translation layer in `platform/darwin/lib/`. No new directories required beyond feature-specific settings modules.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations - table not needed.
