# Implementation Plan: Modularize Flake Configuration Libraries

**Branch**: `011-modularize-flake-libs` | **Date**: 2025-11-01 | **Spec**: [spec.md](./spec.md)\
**Input**: Feature specification from `/specs/011-modularize-flake-libs/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

This feature refactors the flake.nix configuration to improve modularity by:

1. **Auto-discovering** users and profiles from directory structure using `builtins.readDir`
1. **Modularizing** platform-specific configuration helpers into respective lib files:
   - Darwin configuration → `system/darwin/lib/darwin.nix`
   - NixOS configuration → `system/nixos/lib/nixos.nix`
   - Home Manager standalone → `user/shared/lib/home-manager.nix (merged with bootstrap)`
1. **Platform-agnostic orchestration**: flake.nix becomes a thin layer that only loads platforms that exist

This eliminates hardcoded user/profile lists and colocates platform logic with platform code, reducing maintenance burden and improving code organization per Constitutional principles (v2.0.0).

### Enhanced Architecture (Implemented)

The final implementation achieves **true platform-agnostic design**:

**Problem**: Original design had darwin-specific code in flake.nix even if you never use darwin.

**Solution**: Each platform lib exports complete outputs:

```nix
# system/darwin/lib/darwin.nix
outputs = {
  darwinConfigurations = { ... };  # All darwin configs
  formatter.aarch64-darwin = ...;  # Darwin formatter  
  validProfiles.darwin = ...;      # Darwin profiles
}

# flake.nix - just orchestrates
darwinOutputs = if pathExists ./system/darwin/lib/darwin.nix
  then (import ...).outputs
  else {};
```

**Benefits**:

- No darwin code loaded if you only use NixOS
- Each platform completely self-contained
- Perfect separation of concerns
- Easy to add new platforms (just create lib file)

## Technical Context

**Language/Version**: Nix 2.19+ (flakes enabled)\
**Primary Dependencies**:

- nix-darwin (macOS system management)
- home-manager (user environment management)
- nixpkgs-unstable

**Storage**: File system (Nix expressions in .nix files, directory scanning)\
**Testing**:

- `nix flake check` (flake validation)
- `nix build .#darwinConfigurations.<config>.system` (config builds)
- `just` commands (user-facing interface validation)

**Target Platform**: Multi-platform (darwin, nixos, standalone home-manager)\
**Project Type**: Single configuration repository\
**Performance Goals**:

- Flake evaluation time: \<30 seconds (constitutional requirement)
- Directory scanning overhead: negligible (\<1 second for ~10 users/profiles)

**Constraints**:

- Pure functional Nix expressions (no side effects during evaluation)
- Backward compatibility (all 4 existing darwin configs must build)
- Constitutional compliance (\<200 lines per module where applicable)

**Scale/Scope**:

- 3 users currently (cdrokar, cdrolet, cdrixus)
- 2 darwin profiles, 3 linux profiles (placeholders)
- ~150 lines currently in flake.nix (target: reduce by 30%+)
- Auto-discovery scales to dozens of users/profiles

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Core Principles Alignment (Constitution v2.0.3)

**✅ I. Declarative Configuration First**

- All changes are declarative Nix expressions
- Auto-discovery uses pure functions (`builtins.readDir`)
- No imperative scripts or stateful operations

**✅ II. Modularity and Reusability**

- Refactoring improves modularity by separating platform concerns
- Helper functions become reusable lib modules
- Auto-discovery eliminates duplication across platforms

**✅ III. Documentation-Driven Development**

- Specification complete with user stories and acceptance criteria
- Implementation plan documents technical approach
- Quickstart will provide clear examples

**✅ IV. Purity and Reproducibility**

- Directory scanning is deterministic (same dirs → same results)
- No network access or system state dependencies
- Pure functional transformations throughout

**✅ V. Cross-Platform Compatibility**

- Platform-specific logic isolated to platform lib files
- Shared patterns unified in directory scanning approach
- Works across darwin, nixos, standalone home-manager

### Architectural Standards (Constitution v2.0.3)

**✅ Directory Structure Standard**

- Aligns with established user/system hierarchy
- Lib files go in proper platform locations:
  - `system/darwin/lib/darwin.nix`
  - `system/nixos/lib/nixos.nix`
  - `user/shared/lib/home-manager.nix` (merged: bootstrap + standalone helper)

**✅ Module Organization Pattern**

- Helper functions are discrete, focused modules
- Directory scanning logic is standalone function
- Each lib file handles one platform's configuration

**✅ Helper Libraries and Activation Scripts**

- Lib files contain reusable helpers (mkDarwinConfig, etc.)
- Follow established lib pattern (accept inputs, return configs)
- Pure functions, no activation scripts needed

### Technical Standards (Constitution v2.0.3)

**✅ Version Control Discipline**

- Changes tracked in feature branch 011-modularize-flake-libs
- Incremental commits per component (discovery, darwin, nixos, etc.)
- No secrets involved (purely structural refactor)

**✅ Testing and Validation**

- Acceptance scenarios define test criteria
- Build validation for all 4 existing configs
- Justfile command validation (list-users, list-profiles)

**✅ Configuration Management**

- Flake.nix remains central coordination point
- Imports lib modules for platform-specific logic
- Auto-discovery provides dynamic outputs

### Feature-Specific Compliance

**✅ App-Centric Organization** (if modules \<200 lines)

- darwin.nix, nixos.nix, home-manager.nix (merged with bootstrap) likely \<100 lines each
- Discovery logic compact (\<50 lines)
- Well within constitutional limits

**✅ No Unnecessary Complexity**

- Simplifies flake.nix (removes hardcoded lists)
- Standard Nix patterns (builtins.readDir, imports)
- No new dependencies or frameworks

**GATE RESULT**: ✅ PASS - All constitutional requirements satisfied

## Project Structure

### Documentation (this feature)

```text
specs/011-modularize-flake-libs/
├── spec.md              # Feature specification (COMPLETE)
├── plan.md              # This file (IN PROGRESS)
├── research.md          # Phase 0 output (PENDING)
├── data-model.md        # Phase 1 output (PENDING)
├── quickstart.md        # Phase 1 output (PENDING)
└── tasks.md             # Phase 2 output (via /speckit.tasks - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
# Current structure (pre-refactor)
flake.nix                          # Contains all helpers + hardcoded lists (150+ lines)
user/
├── cdrokar/default.nix
├── cdrolet/default.nix
├── cdrixus/default.nix
└── shared/lib/
    └── home-manager.nix           # Bootstrap module (keep as-is)

system/
├── darwin/
│   ├── lib/
│   │   ├── mac.nix                # Existing helper lib
│   │   ├── dock.nix               # Existing helper lib
│   │   ├── power.nix              # Existing helper lib
│   │   └── system-defaults.nix    # Existing helper lib
│   ├── profiles/
│   │   ├── home-macmini-m4/
│   │   └── work/
│   ├── settings/                  # System defaults modules
│   └── app/                       # Darwin-specific apps
├── nixos/
│   ├── lib/                       # Empty (placeholders)
│   └── profiles/                  # Empty (placeholders)
└── shared/
    ├── app/                       # Cross-platform apps
    ├── settings/                  # Shared settings
    └── lib/                       # Shared helpers

# Target structure (post-refactor)
flake.nix                          # Coordinator: imports libs, uses discovery (~100 lines)
user/
└── shared/lib/
    └── home-manager.nix           # UPDATED: Bootstrap module + standalone helper (merged)

system/
├── darwin/lib/
│   └── darwin.nix                 # NEW: mkDarwinConfig + darwin-specific logic
├── nixos/lib/
│   └── nixos.nix                  # NEW: mkNixosConfig + nixos-specific logic
└── shared/lib/
    └── discovery.nix              # NEW: Auto-discovery functions (or inline in flake)
```

**Structure Decision**: Single configuration repository with modular lib files. The refactor moves helper functions from flake.nix into platform-specific lib files (`darwin.nix`, `nixos.nix`, `home-manager.nix (merged with bootstrap)`) and adds auto-discovery logic to scan directories. No new directories created - only new .nix files in existing lib/ directories.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No constitutional violations. This refactor simplifies rather than complicates the codebase.

______________________________________________________________________

## Phase 0: Research

### Research Questions

Based on Technical Context, these areas require investigation:

1. **Nix Directory Scanning**:

   - How to use `builtins.readDir` effectively in flakes
   - Filtering for directories with `default.nix`
   - Performance implications of directory scanning in flake evaluation
   - Best practices for error handling (malformed directories, permission issues)

1. **Module Imports and Exports**:

   - Proper pattern for lib file exports (attrset with functions)
   - How to import lib files in flake.nix (relative paths, `import ./path`)
   - Passing flake inputs to lib functions
   - Ensuring functions have access to nixpkgs, specialArgs, etc.

1. **Dynamic Configuration Generation**:

   - How to programmatically generate darwinConfigurations attrset
   - Using `builtins.listToAttrs` or `lib.mapAttrs` for config generation
   - Ensuring generated configs have proper names (user-profile format)
   - Handling platform-specific profile discovery (darwin vs nixos subdirs)

1. **Backward Compatibility**:

   - Ensuring refactored helpers produce identical outputs
   - Testing strategy for configuration equivalence
   - Migration path (can be atomic commit vs gradual)

### Research Tasks

1. **Task R1**: Research Nix `builtins.readDir` usage patterns in flakes

   - Examine existing flakes using directory scanning
   - Document best practices for filtering and error handling
   - Determine if `builtins.attrNames (builtins.readDir path)` is sufficient

1. **Task R2**: Research flake lib module patterns

   - Study nix-darwin and home-manager lib structures
   - Document export patterns (attrset vs function vs both)
   - Determine how to pass flake inputs through lib functions

1. **Task R3**: Research dynamic configuration generation

   - Examine nixpkgs/flakes using programmatic config generation
   - Document `lib.genAttrs`, `lib.mapAttrs`, `builtins.listToAttrs` usage
   - Determine best approach for user×profile combinatorics

1. **Task R4**: Analyze current mkDarwinConfig implementation

   - Document current behavior: inputs, outputs, dependencies
   - Identify what needs to be preserved vs refactored
   - Plan migration to maintain exact same behavior

**Output**: research.md documenting findings, patterns, and decisions

______________________________________________________________________

## Phase 1: Design

**Prerequisites**: research.md complete with all decisions documented

### Data Model (data-model.md)

This refactor has minimal data modeling (structural, not domain data):

**Entity: User Discovery Result**

```nix
{
  name = "cdrokar";          # Directory name
  path = ./user/cdrokar;     # Absolute path to user dir
  valid = true;              # Has default.nix and imports successfully
}
```

**Entity: Profile Discovery Result**

```nix
{
  name = "home-macmini-m4";  # Directory name
  platform = "darwin";       # Parent platform (darwin/nixos)
  path = ./system/darwin/profiles/home-macmini-m4;
  valid = true;              # Has default.nix and imports successfully
}
```

**Entity: Helper Function Signature**

```nix
mkDarwinConfig = {
  user,                      # String: discovered user name
  profile,                   # String: discovered profile name
  system ? "aarch64-darwin", # String: target system architecture
}: <nixos-system-derivation>
```

### Contracts (contracts/)

No external API contracts - this is internal refactoring. The "contracts" are:

**Contract 1: flake.nix outputs (unchanged)**

```nix
# inputs (unchanged)
inputs.nixpkgs, inputs.nix-darwin, inputs.home-manager, etc.

# outputs.validUsers (auto-discovered)
validUsers = [ "cdrokar" "cdrolet" "cdrixus" ];  # scanned from user/

# outputs.validProfiles (auto-discovered)
validProfiles = {
  darwin = [ "home-macmini-m4" "work" ];         # scanned from system/darwin/profiles/
  linux = [ "gnome-desktop-1" "kde-desktop-1" "server-1" ];  # scanned from system/nixos/profiles/
};

# outputs.darwinConfigurations (generated dynamically)
darwinConfigurations = {
  cdrokar-home-macmini-m4 = <derivation>;       # user × profile combination
  cdrokar-work = <derivation>;
  cdrolet-work = <derivation>;
  cdrixus-home-macmini-m4 = <derivation>;
};

# outputs.nixosConfigurations (placeholder, same pattern)
nixosConfigurations = {};

# outputs.homeConfigurations (placeholder, same pattern)
homeConfigurations = {};
```

**Contract 2: Helper Function Interfaces**

```nix
# system/darwin/lib/darwin.nix
{
  # Main export: darwin configuration builder
  mkDarwinConfig = { user, profile, system ? "aarch64-darwin" }: <derivation>;
  
  # Optional: helper utilities
  mkDarwinModules = [ ... ];  # Shared darwin modules
}

# system/nixos/lib/nixos.nix
{
  mkNixosConfig = { user, profile, system ? "x86_64-linux" }: <derivation>;
}

# user/shared/lib/home-manager.nix (merged with bootstrap)
{
  mkHomeConfig = { user, system }: <derivation>;
}
```

### Quick Start (quickstart.md)

**Test 1: Auto-Discovery Validation**

```bash
# Add a new user
mkdir -p user/testuser
echo '{ }' > user/testuser/default.nix

# Verify auto-discovery
nix eval .#validUsers
# Expected: [ "cdrokar" "cdrolet" "cdrixus" "testuser" ]

# Verify justfile sees it
just list-users
# Expected: testuser appears in list
```

**Test 2: Helper Function Usage**

```bash
# Build using darwin.nix helper
nix build .#darwinConfigurations.cdrokar-home-macmini-m4.system

# Verify it builds successfully (same as before refactor)
# Should see: building derivation, no errors
```

**Test 3: Profile Discovery**

```bash
# Add a new darwin profile
mkdir -p system/darwin/profiles/test-profile
echo '{ system.stateVersion = 5; }' > system/darwin/profiles/test-profile/default.nix

# Verify auto-discovery
nix eval .#validProfiles.darwin
# Expected: [ "home-macmini-m4" "work" "test-profile" ]

just list-profiles darwin
# Expected: test-profile appears
```

**Test 4: End-to-End Configuration Generation**

```bash
# Verify all configurations generated correctly
nix flake show | grep darwinConfigurations
# Expected: All 4+ user-profile combinations listed

# Build each one
for config in cdrokar-home-macmini-m4 cdrokar-work cdrolet-work cdrixus-home-macmini-m4; do
  echo "Testing $config..."
  nix build .#darwinConfigurations.$config.system --dry-run
done
# Expected: All dry-runs succeed
```

______________________________________________________________________

## Phase 2: Tasks

**Phase 2 is completed by running `/speckit.tasks`** - NOT by this plan command.

The tasks will be generated in `tasks.md` based on this plan and will break down the implementation into actionable items covering:

1. **Auto-discovery implementation** (builtins.readDir, filtering)
1. **darwin.nix creation** (move mkDarwinConfig, test)
1. **nixos.nix creation** (move mkNixosConfig, prepare structure)
1. **home-manager.nix (merged with bootstrap) creation** (move mkHomeConfig, prepare structure)
1. **flake.nix refactor** (import libs, use discovery, remove hardcoded lists)
1. **justfile updates** (if needed - use auto-discovered lists)
1. **Validation testing** (all 4 configs build, flake check passes)
1. **Documentation updates** (README, CLAUDE.md references)

______________________________________________________________________

## Dependencies

- **External**: None (all dependencies already in flake inputs)
- **Internal**:
  - Current flake.nix structure (reference implementation)
  - Existing lib files (patterns to follow)
  - Constitutional standards (v2.0.3)

______________________________________________________________________

## Risks and Mitigation

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Directory scanning performance degradation | Medium (slower flake eval) | Low | Benchmark with 10+ users; Nix caches evaluations |
| Breaking existing configurations | High (users can't build) | Low | Thorough testing; atomic refactor; git rollback |
| Discovery picking up invalid dirs | Medium (flake errors) | Medium | Require default.nix; validate imports; clear error messages |
| Helper functions lose functionality | High (configs don't work) | Low | Copy exact logic; test outputs identical; incremental migration |
| Justfile assumptions break | Medium (CLI unusable) | Low | Update justfile alongside flake; test all commands |

______________________________________________________________________

## Success Metrics

From spec.md Success Criteria:

- **SC-001**: Adding new user = create directory only ✓ (via auto-discovery)
- **SC-002**: Adding new profile = create directory only ✓ (via auto-discovery)
- **SC-003**: All 4 existing darwin configs build ✓ (validation test)
- **SC-004**: flake.nix reduced by ≥30% lines ✓ (measure before/after)
- **SC-005**: `nix flake show` displays correctly ✓ (manual inspection)
- **SC-006**: `just list-users` works ✓ (test command)
- **SC-007**: `just list-profiles [platform]` works ✓ (test command)
- **SC-008**: Helpers in lib files ✓ (code structure validation)
- **SC-009**: Platform logic isolated ✓ (darwin.nix, nixos.nix exist)
- **SC-010**: Justfile validates correctly ✓ (test with invalid user/profile)

______________________________________________________________________

## Implementation Notes

### Priority Order (MVP First)

**P1 (MVP)**: Auto-discovery + darwin.nix

- Get user/profile discovery working
- Move darwin helpers to darwin.nix
- Validate all 4 darwin configs still build
- **Delivers**: Core value (no manual list updates, modular darwin logic)

**P2**: nixos.nix structure

- Create nixos.nix with mkNixosConfig
- Prepare for future NixOS configs
- **Delivers**: Consistency, future-proofing

**P3**: home-manager.nix (merged with bootstrap)

- Create standalone Home Manager helper
- **Delivers**: Completeness for all platforms

### Incremental Delivery Strategy

1. **Commit 1**: Add discovery functions (inline or lib)
1. **Commit 2**: Create darwin.nix, update flake to use it
1. **Commit 3**: Validate and fix any issues
1. **Commit 4**: Create nixos.nix (structure only)
1. **Commit 5**: Create home-manager.nix (merged with bootstrap) (structure only)
1. **Commit 6**: Update justfile (if needed)
1. **Commit 7**: Documentation updates

Each commit is independently testable and can be reverted if needed.

### Testing Strategy

**Unit level** (per component):

- Discovery function: test with mock directory structures
- Helper functions: test that outputs match current flake.nix outputs

**Integration level**:

- Full flake evaluation: `nix flake check`
- Each configuration: `nix build .#darwinConfigurations.*.system`
- Justfile commands: `just list-users`, `just list-profiles`

**Regression level**:

- Compare before/after derivations (should be identical)
- Test all 4 existing configs build successfully
- Verify flake show output unchanged (except more dynamic)

______________________________________________________________________

## Open Questions

None - all technical approaches covered in Phase 0 research.

______________________________________________________________________

**Next Steps**: Run `/speckit.tasks` to generate the tasks.md implementation breakdown.
