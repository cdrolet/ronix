# Research: Host/Family Architecture Refactoring

**Feature**: 021-host-family-refactor\
**Phase**: Phase 0 - Research & Technical Decisions\
**Date**: 2025-12-02

## Overview

This document consolidates research findings for implementing the host/family architecture. All technical decisions made during Phase 0 are documented here with rationale and alternatives considered.

## Decision 1: Hierarchical Discovery Function

**Question**: How should discovery system be extended for platform → family → shared search?

**Decision**: Three-tier search with first-match semantics

**Search Order**:

1. `platform/{platform}/{itemType}/` - Platform-specific
1. `platform/shared/family/{family}/{itemType}/` - Family-specific (if family defined)
1. `platform/shared/{itemType}/` - Shared fallback

**Rationale**:

- **First-match** (not collection): Prevents ambiguous merging, matches user expectations for override behavior
- **Three tiers**: Provides platform-specific override, family grouping, and shared fallback
- **Conditional tier 2**: Cleanly skips family search when host.family is null

**Alternatives Considered**:

- ❌ Collection/merging across tiers: Too complex, unpredictable behavior
- ❌ Two-tier only (no family): Doesn't meet requirements for reusable familys
- ❌ Family as first tier: Wrong priority - platform-specific should override family

**Function Signature**:

```nix
discoverWithHierarchy = {
  itemName,          # String: app/setting name
  itemType,          # String: "app" or "setting"
  platform,          # String: "darwin", "nixos"
  family ? null,     # String | null: optional family
  basePath,          # Path: repository root
}: # Returns: Path | null
```

**Benefits**:

- Self-documenting (named parameters)
- Clean optional parameter handling
- Matches Nix conventions

## Decision 2: Family Resolution Strategy

**Question**: How should platform libs resolve family references efficiently?

**Decision**: Direct path construction with existence checks

**Implementation**:

```nix
# In platform library (darwin.nix)
hostData = import ../host/${hostName} { };
hostFamily = hostData.family or null;

# Construct family path
familyPath = if hostFamily != null 
  then ../../shared/family/${hostFamily}
  else null;

# Auto-install family defaults if they exist
familyDefaults = if familyPath != null then [
  (lib.optional (builtins.pathExists (familyPath + "/app/default.nix"))
    (familyPath + "/app/default.nix"))
  (lib.optional (builtins.pathExists (familyPath + "/settings/default.nix"))
    (familyPath + "/settings/default.nix"))
] else [];
```

**Rationale**:

- Simple and efficient (no caching needed at small scale)
- Explicit existence checks prevent errors
- Auto-installation via conditional imports

**Alternatives Considered**:

- ❌ Caching family paths: Premature optimization for 2-3 familys
- ❌ Discovery function for familys: Overkill, direct path construction is clearer
- ❌ Always importing defaults: Would require error handling for missing files

## Decision 3: Settings vs Applications Resolution

**Question**: Why do settings prohibit "\*" but applications allow it?

**Decision**: Different semantics based on actual usage patterns

**Applications**:

- ✅ Allow "\*" wildcard - imports all discovered apps
- Use case: User wants everything (power user, testing)
- Discovery finds all .nix files in search path

**Settings**:

- ❌ Prohibit "\*" wildcard - too broad, unexpected behavior
- ✅ Allow "default" keyword - imports all settings in **platform** only
- Use case: Platform-specific default bundle (see darwin/settings/default.nix)
- Validates to prevent accidental "\*" usage

**Rationale**:

- Apps are additive (more apps = more tools, usually harmless)
- Settings are system configuration (more settings = potential conflicts, overrides)
- "default" is platform-scoped to prevent cascading imports from shared
- Existing darwin/settings/default.nix pattern already works this way

**Validation**:

```nix
# In platform library
if builtins.elem "*" hostSettings then
  throw ''
    Settings array cannot use "*" wildcard.
    Use "default" to import all platform settings, or list specific settings.
    Host: ${hostName}
    Invalid settings array: ${toString hostSettings}
  ''
else ...
```

**Alternatives Considered**:

- ❌ Allow "\*" for settings: Too dangerous, could import conflicting configs
- ❌ No "default" keyword: Would require listing all settings manually (verbose)
- ❌ "default" searches all tiers: Could cause unintended cascading imports

## Decision 4: Migration Path

**Question**: Can familys be migrated to hosts without breaking existing builds?

**Decision**: Yes - pure data transformation is straightforward

**Migration Procedure**:

1. **Rename directory** (preserves git history):

   ```bash
   git mv platform/darwin/familys platform/darwin/host
   ```

1. **Transform each family to pure data**:

   ```nix
   # Before (family with imports)
   { config, pkgs, lib, ... }:
   {
     imports = [
       ../../../shared/lib/host.nix
       ../../settings/default.nix
     ];
     host = {
       name = "home-macmini";
       display = "Home Mac Mini";
       platform = "aarch64-darwin";
     };
   }

   # After (pure data host)
   { ... }:
   {
     name = "home-macmini";
     applications = [];           # Apps now explicit
     settings = [ "default" ];    # Replaces import ../../settings/default.nix
     # family = ["work"];           # Optional, not in this example
   }
   ```

1. **Update platform lib** (darwin.nix) to:

   - Load host as pure data (Feature 020 pattern)
   - Extract applications and settings arrays
   - Generate imports using hierarchical discovery
   - Import family defaults if family defined

1. **Update flake.nix**:

   - No changes needed - discoverFamilys already finds directories
   - Just need to update discovery function name if desired (optional)

1. **Update justfile**:

   - Change: `just install <user> <family>` help text
   - To: `just install <user> <host>` (terminology update)

**Test Plan**:

1. Build current family: `nix build ".#darwinConfigurations.cdrokar-home-macmini-m4.system"`
1. Apply migration
1. Build migrated host with same command
1. Verify identical closure (same packages, settings)

**Rationale**:

- Pure data transformation is mechanical (no logic changes)
- Feature 020 proved this pattern works for user configs
- Git history preserved via `git mv`
- Existing builds continue to work during migration

**Alternatives Considered**:

- ❌ Backward compatibility layer: Unnecessary complexity for 2 familys
- ❌ Gradual migration: All-at-once is cleaner with only 2 familys
- ❌ New directory name: "host" clearly communicates the change from "family"

## Decision 5: Default Auto-Installation

**Question**: How should automatic installation of family defaults work?

**Decision**: Conditional imports based on pathExists

**Implementation**:

```nix
# In platform library (darwin.nix)
let
  hostFamily = hostData.family or null;
  
  familyDefaults = 
    if hostFamily != null then
      lib.flatten [
        (lib.optional 
          (builtins.pathExists (../../shared/family/${hostFamily}/app/default.nix))
          (../../shared/family/${hostFamily}/app/default.nix))
        (lib.optional 
          (builtins.pathExists (../../shared/family/${hostFamily}/settings/default.nix))
          (../../shared/family/${hostFamily}/settings/default.nix))
      ]
    else
      [];
in {
  imports = [
    hostData                    # Pure host data
    generatedAppImports         # From host.applications array
    generatedSettingImports     # From host.settings array
  ] ++ familyDefaults;          # Auto-installed family defaults
}
```

**Behavior**:

- If `family` is null/undefined: No family defaults attempted
- If `family` is defined but `app/default.nix` doesn't exist: Silently skipped (optional)
- If `family` is defined and `app/default.nix` exists: Auto-imported
- Same logic for `settings/default.nix`

**Rationale**:

- Family defaults are optional (not all familys need them)
- pathExists prevents errors from missing files
- Auto-installation is convenient but doesn't force structure
- Follows "convention over configuration" - defaults exist where sensible

**Alternatives Considered**:

- ❌ Require defaults: Too rigid, not all familys need defaults
- ❌ Manual import in host: Defeats purpose of auto-installation
- ❌ Error if family referenced but no defaults: Too strict, defaults are optional

## Supporting Technologies

**No new technologies required**. Using existing:

- Nix 2.19+ with flakes
- nixpkgs lib (builtins.readDir, builtins.pathExists, lib.filter\*, lib.optional)
- Platform libraries (darwin.nix pattern from Feature 020)
- Discovery system (extending existing discovery.nix)

## Integration with Feature 020

This feature mirrors and extends Feature 020's successful pattern:

| Aspect | Feature 020 (Users) | Feature 021 (Hosts) |
|--------|---------------------|---------------------|
| **Entity** | User configurations | Host configurations |
| **Pure Data** | ✅ user/*/default.nix | ✅ platform/*/host/\*/default.nix |
| **Arrays** | applications | applications, settings |
| **Optional Field** | N/A | family (references shared familys) |
| **Search Tiers** | 2 (platform, shared) | 3 (platform, family, shared) |
| **Orchestration** | Platform lib loads + generates | Platform lib loads + generates |
| **Pattern** | Pre-eval extraction | Pre-eval extraction |

**Key Similarity**: Both extract data BEFORE module evaluation to avoid infinite recursion.

**Key Difference**: Hosts add hierarchical search with optional family tier.

## Best Practices Applied

**From Nix Community**:

- Pure functions for discovery (no side effects)
- Early validation with clear error messages
- pathExists for conditional imports (safe)
- Optional parameters with sensible defaults

**From Constitution**:

- \<200 lines per module
- Pure data for configurations
- Platform-agnostic design (works on any platform)
- Documentation-driven development

**From Feature 020**:

- Pure data pattern (proven successful)
- Pre-evaluation extraction (avoids infinite recursion)
- Platform lib orchestration (users see simple interface)
- Comprehensive testing before deployment

## Risks & Mitigations

### Risk 1: Hierarchical search complexity

**Impact**: Medium\
**Mitigation**:

- Keep first-match semantics simple
- Comprehensive unit tests
- Clear documentation with examples

### Risk 2: Migration breaks existing builds

**Impact**: High\
**Mitigation**:

- Test migration on copy before committing
- Verify identical closure after migration
- Git history preserved for easy rollback

### Risk 3: Family confusion

**Impact**: Low\
**Mitigation**:

- Clear naming (family vs family vs host)
- Quickstart.md with examples
- Validation errors explain concepts

### Risk 4: Settings "\*" misuse

**Impact**: Low\
**Mitigation**:

- Validate and throw clear error
- Document why "\*" not allowed for settings
- Suggest "default" alternative

## Phase 0 Completion Checklist

- [x] **Research Task 1**: Hierarchical discovery pattern designed
- [x] **Research Task 2**: Family resolution strategy defined
- [x] **Research Task 3**: Settings vs applications rationale documented
- [x] **Research Task 4**: Migration path validated
- [x] **Research Task 5**: Default auto-installation pattern designed
- [x] **Technologies**: No new deps, using existing Nix + nixpkgs
- [x] **Best Practices**: Documented and applied
- [x] **Risks**: Identified with mitigations
- [x] **Ready for Phase 1**: All unknowns resolved ✅

## Next Steps

Proceed to **Phase 1: Design & Contracts**:

1. Generate data-model.md (entities, relationships, validation rules)
1. Generate contracts/ (host schema, family schema)
1. Generate quickstart.md (examples for common use cases)
1. Update agent context with this feature's additions
