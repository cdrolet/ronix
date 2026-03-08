# Implementation Plan: User Wallpaper Configuration

**Branch**: `033-user-wallpaper-config` | **Date**: 2025-12-30 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/033-user-wallpaper-config/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Enable users to declaratively configure desktop wallpapers via file paths in their user configuration. The implementation supports both Darwin (macOS) and GNOME desktop environments with platform-agnostic user syntax. Wallpapers are applied using platform-specific APIs (macOS `osascript` for Darwin, `dconf/gsettings` for GNOME) while maintaining a consistent user interface across platforms.

## Technical Context

**Language/Version**: Nix 2.19+ with flakes enabled\
**Primary Dependencies**: Home Manager, nix-darwin (macOS), NixOS modules (GNOME), dconf (GNOME gsettings)\
**Storage**: File system (wallpaper image files), user configuration (Nix expressions)\
**Testing**: Manual testing (`nix build`, visual verification on darwin/GNOME), `nix flake check` for syntax\
**Target Platform**: Darwin (macOS), NixOS with GNOME desktop\
**Project Type**: Single project (system configuration repository)\
**Performance Goals**: Wallpaper application within 5 seconds of system activation\
**Constraints**: Must support common image formats (jpg, png, jpeg, heic, webp), must not fail build on invalid paths\
**Scale/Scope**: Single user configuration field (`user.wallpaper`), 2 platform implementations (darwin, GNOME)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Core Principles Compliance

**I. Declarative Configuration First**: ✅ PASS

- Wallpaper configuration declared in `user.wallpaper` field
- No imperative commands required from user
- System activation applies wallpaper declaratively

**II. Modularity and Reusability**: ✅ PASS

- Platform-specific implementations in appropriate directories:
  - Darwin: `system/darwin/settings/wallpaper.nix`
  - GNOME: `system/shared/family/gnome/settings/wallpaper.nix`
- Single user configuration field works across platforms
- Module size under 200 lines (estimated ~50-80 lines per platform)

**III. Documentation-Driven Development**: ✅ PASS

- Specification created (spec.md)
- Implementation plan in progress (plan.md)
- User documentation will be added to CLAUDE.md

**IV. Purity and Reproducibility**: ⚠️ NEEDS ATTENTION

- Wallpaper file paths reference external files (not in Nix store)
- Users manage wallpaper files independently
- Configuration is reproducible IF wallpaper files exist at specified paths
- **Mitigation**: Validate file existence, log warnings for missing files, don't fail build

**V. Testing and Validation**: ✅ PASS

- `nix flake check` validates syntax
- Manual visual verification on each platform
- Graceful degradation for missing/invalid files

**VI. Cross-Platform Compatibility**: ✅ PASS

- Single user syntax: `user.wallpaper = "/path/to/image.jpg"`
- Platform-specific implementation hidden from user
- Darwin settings in `system/darwin/settings/`
- GNOME settings in `system/shared/family/gnome/settings/`

### Architectural Standards Compliance

**Flakes as Entry Point**: ✅ PASS

- No changes to flake structure required
- Settings auto-discovered via existing discovery system

**Home Manager Integration**: ✅ PASS

- Wallpaper configuration via Home Manager modules
- Uses existing user configuration pattern

**Directory Structure Standard**: ✅ PASS

- Darwin: `system/darwin/settings/wallpaper.nix`
- GNOME: `system/shared/family/gnome/settings/wallpaper.nix`
- Follows hierarchical user/system split

### Development Standards Compliance

**Specification Management**: ✅ PASS

- Feature specification created
- Implementation plan following template

**Configuration Module Organization**: ✅ PASS

- Single responsibility: wallpaper configuration only
- Size limit: Under 200 lines per module
- Clear naming: `wallpaper.nix`
- Will use `lib.mkDefault` for user overridability

**Platform-Specific Code**: ✅ PASS

- Darwin implementation isolated in darwin/settings/
- GNOME implementation isolated in gnome/settings/
- No platform conditionals in shared code

**Helper Libraries**: ✅ RESOLVED (Post-Design)

- Path validation/expansion will use inline Nix lib functions (`lib.hasPrefix`, `lib.removePrefix`)
- Extension validation uses `lib.hasSuffix` and `lib.any`
- No new helper library needed - existing lib functions sufficient
- URI formatting for GNOME: simple string interpolation (`"file://${path}"`)

### Quality Assurance Compliance

**Pre-Deployment Checks**: ✅ PASS

- Will verify with `nix flake check`
- Manual testing on both platforms

**Performance Constraints**: ✅ PASS

- Minimal closure size impact (no new packages)
- Wallpaper application during activation (acceptable delay)

**Security Requirements**: ✅ PASS

- No secrets involved
- File path validation prevents injection attacks
- Read-only access to wallpaper files

### Summary - Post-Design Re-Evaluation

**Constitution Compliance**: ✅ FULL PASS

All concerns from initial check have been resolved:

1. **Purity concern** (RESOLVED):

   - External file dependencies are inherent to wallpaper feature
   - Mitigation: Validation with `config.warnings`, graceful degradation
   - Build never fails due to missing wallpaper (cosmetic feature)
   - Follows existing patterns from dock.nix (path filtering)

1. **Helper libraries** (RESOLVED):

   - No new helper library needed
   - Uses existing lib functions: `lib.hasPrefix`, `lib.removePrefix`, `lib.hasSuffix`, `lib.any`
   - Path expansion: inline logic (6 lines)
   - URI formatting: string interpolation (1 line)
   - Extension validation: standard lib pattern (3 lines)

**Design Decisions Validated**:

- ✅ Darwin: osascript with runtime validation (no dependencies)
- ✅ GNOME: dconf.settings (declarative, integrated)
- ✅ Validation: config.warnings + runtime checks (non-blocking)
- ✅ Module size: Estimated ~60 lines darwin, ~40 lines GNOME (well under 200 limit)

No constitutional violations. Feature fully compliant with all principles and standards.

## Project Structure

### Documentation (this feature)

```text
specs/033-user-wallpaper-config/
├── spec.md              # Feature specification (completed)
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (next step)
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── contracts/           # Phase 1 output (if needed)
```

### Source Code (repository root)

```text
system/
├── darwin/
│   └── settings/
│       └── wallpaper.nix          # Darwin wallpaper implementation (NEW)
│
└── shared/
    └── family/
        └── gnome/
            └── settings/
                └── wallpaper.nix  # GNOME wallpaper implementation (NEW)

user/
└── shared/
    └── lib/
        └── wallpaper-helpers.nix  # Path validation helpers (NEW, if needed)
```

**Structure Decision**: Using platform-specific settings pattern established by constitution. Darwin settings go in `system/darwin/settings/`, GNOME family settings go in `system/shared/family/gnome/settings/`. Both modules will be auto-discovered by existing discovery system. User configuration remains platform-agnostic in `user/{username}/default.nix`.

**Files to Create**:

1. `system/darwin/settings/wallpaper.nix` - macOS implementation using `osascript`
1. `system/shared/family/gnome/settings/wallpaper.nix` - GNOME implementation using dconf
1. Optional: `user/shared/lib/wallpaper-helpers.nix` - Path validation and format checking helpers (if needed based on Phase 0 research)

**Integration Points**:

- Existing settings discovery system (`system/darwin/settings/default.nix` and `system/shared/family/gnome/settings/default.nix`)
- User configuration schema (`config.user.wallpaper`)
- Home Manager activation hooks (for applying wallpaper during system activation)

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations to justify. Feature complies with all constitutional requirements.
