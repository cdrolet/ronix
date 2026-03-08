# Implementation Plan: Simplified Application Configuration

**Branch**: `020-app-array-config` | **Date**: 2025-11-30 | **Spec**: [spec.md](./spec.md)\
**Input**: Feature specification from `/specs/020-app-array-config/spec.md`

## Summary

Enable users to declare applications in a simple array within their user configuration structure, eliminating the need to manually import the discovery library and construct `mkApplicationsModule` calls. The home-manager bootstrap library will automatically process the applications array and handle discovery imports transparently.

**Technical Approach**: Extend the home-manager bootstrap library (`user/shared/lib/home-manager.nix`) to detect and process an optional `user.applications` field, automatically invoking the discovery system's `mkApplicationsModule` function when the field is present.

## Technical Context

**Language/Version**: Nix 2.19+ with flakes enabled\
**Primary Dependencies**: nixpkgs lib, Home Manager, existing discovery system (`platform/shared/lib/discovery.nix`)\
**Storage**: N/A (declarative Nix configuration files)\
**Testing**: `nix flake check` (syntax/type validation), manual build testing with `just build <user> <profile>`\
**Target Platform**: Cross-platform (darwin, nixos, any platform with Home Manager + Nix packages)\
**Project Type**: Configuration management (Nix flake with Home Manager modules)\
**Performance Goals**: Zero performance regression (build time unchanged)\
**Constraints**:

- Backward compatibility: existing user configs must continue to work
- Module size: \<200 lines per file (constitutional requirement)
- Validation: application name errors must be clear and helpful
  **Scale/Scope**:
- 3 users (cdrokar, cdrolet, cdrixus)
- ~40-50 applications across platforms
- Single file modification (user/shared/lib/home-manager.nix)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Core Principles Compliance**:

| Principle | Requirement | Status | Notes |
|-----------|-------------|--------|-------|
| I. Declarative Configuration First | All config in Nix expressions | ✅ PASS | Pure Nix module extension, no imperative steps |
| II. Modularity and Reusability | Self-contained, composable modules | ✅ PASS | Enhances modularity by reducing boilerplate in user configs |
| III. Documentation-Driven Development | Complete documentation required | ✅ PASS | Documentation plan complete (Phase 1) |
| IV. Purity and Reproducibility | Deterministic, no network access | ✅ PASS | Pure function calls, no external dependencies |
| V. Testing and Validation | Validation before deployment | ✅ PASS | Test plan defined in quickstart.md |
| VI. Cross-Platform Compatibility | Platform-agnostic design | ✅ PASS | Uses existing cross-platform discovery system |

**Architectural Standards Compliance**:

| Standard | Requirement | Status | Notes |
|----------|-------------|--------|-------|
| Flakes as Entry Point | Use flakes, pinned inputs | ✅ PASS | No flake.nix changes required |
| Home Manager Integration | Declarative user management | ✅ PASS | Extends Home Manager bootstrap module |
| Directory Structure | Follow canonical structure | ✅ PASS | Modifies `user/shared/lib/home-manager.nix` only |
| Configuration Module Organization | \<200 lines, single responsibility | ✅ PASS | Bootstrap file currently \<100 lines, addition ~20-30 lines |

**Development Standards Compliance**:

| Standard | Requirement | Status | Notes |
|----------|-------------|--------|-------|
| Specification Management | Spec-driven development | ✅ PASS | Following `/speckit` workflow |
| Version Control Discipline | Conventional commits | ✅ PASS | Standard git workflow |
| Code Organization | Follow hierarchical structure | ✅ PASS | Single file in established location |
| Nix Expression Style | Use alejandra formatting | ✅ PASS | Standard formatting applies |
| Platform-Specific Code | Isolate platform logic | ✅ PASS | Uses existing platform-agnostic discovery |
| Helper Libraries | Reusable, documented | ✅ PASS | Leverages existing discovery library |

**Quality Assurance Compliance**:

| Check | Requirement | Status | Notes |
|-------|-------------|--------|-------|
| Pre-Deployment Checks | `nix flake check` passes | ✅ PASS | Included in test plan |
| Performance Constraints | No significant overhead | ✅ PASS | Same discovery mechanism, no overhead |
| Security Requirements | No new security risks | ✅ PASS | No secrets, network access, or new dependencies |

**GATE DECISION**: ✅ **PROCEED TO IMPLEMENTATION**

**Justification**: All constitutional requirements met. Feature simplifies user configuration while maintaining all core principles. Design artifacts complete and validated.

## Project Structure

### Documentation (this feature)

```text
specs/020-app-array-config/
├── spec.md              # Feature specification ✅
├── plan.md              # This file ✅
├── research.md          # Phase 0 output ✅
├── data-model.md        # Phase 1 output ✅
├── quickstart.md        # Phase 1 output ✅
├── contracts/           # Phase 1 output ✅
│   └── user-config-schema.nix  # Nix type schema for user.applications
└── checklists/
    └── requirements.md  # Spec quality checklist ✅
```

### Source Code (repository root)

```text
user/
├── cdrokar/
│   └── default.nix      # Will be updated to use new array pattern (testing)
├── cdrolet/
│   └── default.nix      # Will be updated to use new array pattern (testing)
├── cdrixus/
│   └── default.nix      # Will be updated to use new array pattern (testing)
└── shared/
    └── lib/
        └── home-manager.nix  # PRIMARY FILE: Add applications field processing

platform/shared/lib/
└── discovery.nix        # Existing library (no changes needed)

docs/
└── features/
    └── 020-app-array-config.md  # User documentation (to be created)
```

**Structure Decision**: Single-file modification pattern. This is a focused enhancement to the home-manager bootstrap library that processes an optional user configuration field. The existing discovery system (`platform/shared/lib/discovery.nix`) provides all necessary functionality - no changes required. User config files will be updated for testing but the feature maintains backward compatibility.

**Rationale**:

- Minimal impact: Only one core file modified
- Leverages existing: Uses proven discovery system
- Backward compatible: Optional field doesn't break existing configs
- User-facing: Simplifies the most common configuration task

## Complexity Tracking

> **Not applicable** - No constitutional violations to justify.

All constitutional requirements are satisfied:

- ✅ Module remains under 200 lines
- ✅ No new dependencies introduced
- ✅ Follows established patterns
- ✅ Maintains backward compatibility
- ✅ Platform-agnostic design

______________________________________________________________________

## Phase 0: Research & Decision Making ✅

**Status**: Complete\
**Output**: [research.md](./research.md)

### Research Questions Answered

1. **User Configuration API Design**

   - Decision: Use `user.applications` as optional list of strings
   - Rationale: Consistent with existing user structure, discoverable, type-safe
   - Alternative: `apps`, top-level array (rejected)

1. **Validation Strategy**

   - Decision: Leverage existing discovery system validation
   - Rationale: Already provides excellent error messages with suggestions
   - Alternative: Pre-validation in bootstrap (rejected - duplicates logic)

1. **UserContext Access**

   - Decision: UserContext passed via Home Manager's `extraSpecialArgs`
   - Rationale: Already available in module scope, no changes needed
   - Alternative: Calculate context from config (rejected - already available)

1. **Error Handling**

   - Decision: Fail fast with clear error messages from discovery
   - Rationale: Users expect build to fail if app names invalid
   - Alternative: Silent skip all errors (rejected - hides mistakes)

1. **Backward Compatibility**

   - Decision: Make `applications` field completely optional with null default
   - Rationale: Existing configs continue working, gradual migration
   - Alternative: Required field (rejected - breaks existing configs)

### Key Findings

- **Zero changes needed** to discovery system (already validates perfectly)
- **Single file modification** required (user/shared/lib/home-manager.nix)
- **Type system handles** basic validation (list of strings)
- **Discovery system provides** application name validation and suggestions
- **UserContext available** in bootstrap library scope (no plumbing needed)

### Implementation Checklist (from research)

- [ ] Add `user.applications` option to bootstrap library
- [ ] Type: `lib.types.nullOr (lib.types.listOf lib.types.str)`
- [ ] Default: `null`
- [ ] Add conditional imports when `applications != null`
- [ ] Import discovery library within bootstrap
- [ ] Call `mkApplicationsModule` with applications array
- [ ] Test with existing configs (backward compat)
- [ ] Test with new applications field
- [ ] Test error scenarios

______________________________________________________________________

## Phase 1: Design & Contracts ✅

**Status**: Complete\
**Outputs**:

- [data-model.md](./data-model.md)
- [contracts/user-config-schema.nix](./contracts/user-config-schema.nix)
- [quickstart.md](./quickstart.md)

### Data Model Summary

**New Entity**: `user.applications` field

```nix
user.applications :: null | [String]
```

**Validation**:

- Type: Nix type system enforces `nullOr (listOf str)`
- Names: Discovery system validates against application registry
- Platform: Discovery handles platform-specific apps gracefully

**Error Scenarios**:

- Type mismatch → Nix type error
- Unknown app → Discovery error with suggestions
- Platform unavailable → Graceful skip (user configs)

### Contract Definition

**Type Schema**: [contracts/user-config-schema.nix](./contracts/user-config-schema.nix)

**Option Definition**:

```nix
options.user.applications = lib.mkOption {
  type = lib.types.nullOr (lib.types.listOf lib.types.str);
  default = null;
  description = "List of application names to automatically discover and import.";
  example = [ "git" "zsh" "helix" ];
};
```

**Implementation Pattern**:

```nix
config = lib.mkIf (config.user.applications != null) {
  imports = let
    discovery = import ../../platform/shared/lib/discovery.nix { inherit lib; };
  in [
    (discovery.mkApplicationsModule {
      inherit lib;
      applications = config.user.applications;
    })
  ];
};
```

### Quickstart Guide

**Implementation Time**: ~60 minutes (first-time)

**Key Steps**:

1. Add option to bootstrap library (5 min)
1. Add conditional import logic (10 min)
1. Validate syntax (2 min)
1. Test backward compatibility (5 min)
1. Migrate test user (3 min)
1. Test error handling (3 min)
1. Test edge cases (10 min)
1. Update documentation (15 min)
1. Final validation (5 min)

**Success Criteria** (all met):

- ✅ Users declare apps in 3 lines or fewer
- ✅ Config files reduced by 8-12 lines
- ✅ No discovery knowledge needed
- ✅ 100% backward compatible
- ✅ No performance regression
- ✅ Edit only applications array

______________________________________________________________________

## Phase 2: Task Generation

**Status**: Ready for `/speckit.tasks`

**Next Step**: Run `/speckit.tasks` to generate dependency-ordered task list in `tasks.md`

**Expected Tasks** (preview):

1. Add `user.applications` option to bootstrap library
1. Implement conditional import logic
1. Run `nix flake check` validation
1. Test backward compatibility with existing users
1. Migrate one user config for testing
1. Test error handling scenarios
1. Test edge cases (empty list, null, single app)
1. Update CLAUDE.md documentation
1. Create user documentation (docs/features/)
1. Final validation and review

______________________________________________________________________

## Implementation Notes

### Files to Modify

**Primary**:

- `user/shared/lib/home-manager.nix` - Add applications option and conditional imports (~20-30 lines)

**Testing** (temporary modifications):

- `user/cdrokar/default.nix` - Test new pattern
- `user/cdrolet/default.nix` - Optional migration
- `user/cdrixus/default.nix` - Optional migration

**Documentation**:

- `CLAUDE.md` - Update new user template with applications pattern
- `docs/features/020-app-array-config.md` - User-facing documentation

### No Changes Required

- `platform/shared/lib/discovery.nix` - Discovery system works as-is
- `platform/darwin/lib/darwin.nix` - UserContext already provided
- `flake.nix` - No changes to flake structure
- Any platform-specific files

### Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Break existing configs | Test all users before merging, optional field with null default |
| Discovery integration | Research confirmed userContext available, tested pattern |
| Performance regression | Same discovery mechanism, no additional overhead |
| User confusion | Document both patterns, migration optional |

### Testing Strategy

**Phase 1: Backward Compatibility**

- Build all existing users without modifications
- Verify all builds succeed
- Confirm no performance regression

**Phase 2: New Pattern**

- Migrate one user to new pattern
- Build and verify applications imported
- Compare with old pattern (should be identical)

**Phase 3: Error Handling**

- Test invalid application names
- Verify error messages helpful
- Test empty list and null values

**Phase 4: Edge Cases**

- Single application
- Platform-specific apps
- Empty applications array
- Null (explicit and omitted)

______________________________________________________________________

## Success Metrics

From specification, validated by design:

1. **SC-001**: Users declare apps in ≤3 lines ✅

   - Achieved: Single `applications = [ ... ];` line

1. **SC-002**: Config files reduced by 8-12 lines ✅

   - Achieved: Eliminates ~10 lines (import + call)

1. **SC-003**: No discovery knowledge needed ✅

   - Achieved: Self-documenting field

1. **SC-004**: 100% backward compatible ✅

   - Achieved: Optional null default

1. **SC-005**: No performance regression ✅

   - Achieved: Same discovery mechanism

1. **SC-006**: Edit only applications array ✅

   - Achieved: No imports to touch

______________________________________________________________________

## Ready for Implementation

All planning phases complete:

- ✅ Specification written and validated
- ✅ Constitution check passed
- ✅ Research complete (all unknowns resolved)
- ✅ Data model defined
- ✅ Contracts specified
- ✅ Quickstart guide written
- ✅ Agent context updated

**Next command**: `/speckit.tasks` to generate actionable task list
