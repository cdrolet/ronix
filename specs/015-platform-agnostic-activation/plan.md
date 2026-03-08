# Implementation Plan: Platform-Agnostic Activation System

**Branch**: `015-platform-agnostic-activation` | **Date**: 2025-11-11 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/015-platform-agnostic-activation/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Replace platform-specific activation tools (darwin-rebuild, nixos-rebuild) with a uniform build-and-activate approach using nix build and built-in activation scripts from configuration outputs. This enables identical commands across all platforms and simplifies adding new platform support.

## Technical Context

**Language/Version**: Nix 2.19+ with flakes, Bash (for justfile recipes)
**Primary Dependencies**:

- nix (flakes-enabled build system)
- just (command runner)
- darwin-rebuild (currently used, to be eliminated from workflows)
- nixos-rebuild (currently used, to be eliminated from workflows)

**Storage**: N/A (configuration management, no persistent storage)
**Testing**: Manual validation via `just build` and `just install` commands, `nix flake check` for syntax
**Target Platform**: Multi-platform (macOS via nix-darwin, Linux via NixOS, extensible to other platforms)
**Project Type**: Infrastructure/Configuration management
**Performance Goals**: Build time within 10% of current baseline (< 30 seconds for incremental builds)
**Constraints**:

- Must maintain backward compatibility with existing configurations
- Must preserve 3-parameter interface (user, platform, profile)
- Activation must handle platform-specific permission requirements (sudo for nixos)

**Scale/Scope**:

- 3 users (cdrokar, cdrolet, cdronix)
- 2 platforms (darwin, nixos)
- ~5 profiles across platforms
- Extensible to additional platforms without code changes

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pre-Design Check

| Principle | Status | Notes |
|-----------|--------|-------|
| Declarative Configuration First | ✅ PASS | Changes are to build/activation interface, all configs remain declarative |
| Modularity and Reusability | ✅ PASS | Centralizes platform-specific paths in single helper function |
| Documentation-Driven Development | ✅ PASS | Specification complete, will update docs after implementation |
| Purity and Reproducibility | ✅ PASS | No changes to build purity, only activation interface |
| Testing and Validation | ✅ PASS | Will validate via manual testing on darwin platform |
| Cross-Platform Compatibility | ✅ PASS | **Core goal of this feature** - improves platform-agnostic design |
| Directory Structure Standard | ✅ PASS | No directory structure changes required |
| Helper Libraries | ✅ PASS | Uses existing justfile helper functions, adds activation script detection |

**Overall**: ✅ **APPROVED** - No constitutional violations. Feature aligns with Core Principle VI (Cross-Platform Compatibility) by improving platform-agnostic design.

## Project Structure

### Documentation (this feature)

```text
specs/015-platform-agnostic-activation/
├── spec.md              # Feature specification (complete)
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output - activation script locations research
├── data-model.md        # Phase 1 output - build/activation workflow model
├── quickstart.md        # Phase 1 output - usage examples
└── contracts/           # Phase 1 output - justfile recipe contracts
    └── justfile-api.md  # Recipe signatures and behavior specifications
```

### Source Code (repository root)

```text
/Users/charles/project/nix-config/
├── justfile             # MODIFIED: Update _rebuild-command to use activation scripts
├── platform/            # Existing platform configurations (unchanged)
│   ├── darwin/
│   │   └── profiles/
│   └── nixos/
│       └── profiles/
└── docs/                # CREATED: User-facing documentation
    └── features/
        └── 015-platform-agnostic-activation.md  # Usage guide
```

**Structure Decision**: This is an infrastructure improvement modifying the existing justfile command interface. No new source directories required. Changes are isolated to:

1. `justfile` - modify `_rebuild-command` helper to use activation scripts instead of external tools
1. `docs/features/` - add user documentation explaining the unified interface

## Complexity Tracking

No constitutional violations to justify.

______________________________________________________________________

## Phase 0: Research & Technical Decisions

### Research Tasks

#### R1: Activation Script Locations and Execution

**Question**: Where are activation scripts located in nix build outputs for darwin and nixos configurations?

**Research Method**:

1. Build a test darwin configuration using `nix build`
1. Inspect `result/` symlink structure
1. Locate activation script for darwin (hypothesis: `result/sw/bin/darwin-rebuild`)
1. Build a test nixos configuration
1. Locate activation script for nixos (hypothesis: `result/bin/switch-to-configuration`)
1. Document exact paths and execution requirements (sudo, arguments)

**Decision Criteria**:

- Scripts must exist in predictable locations
- Scripts must be executable
- Scripts must accept standard arguments (switch, boot, etc.)

**Expected Outcome**: Documented activation script paths for darwin and nixos with execution examples

______________________________________________________________________

#### R2: Activation Script Error Handling

**Question**: How do activation scripts handle errors and what exit codes do they return?

**Research Method**:

1. Execute activation script with intentionally broken configuration
1. Observe error messages and exit codes
1. Test rollback behavior on activation failure
1. Document error handling patterns

**Decision Criteria**:

- Scripts must provide clear error messages
- Scripts must use standard exit codes (0 = success, non-zero = failure)
- Partial activation failures must be detectable

**Expected Outcome**: Error handling patterns and exit code documentation

______________________________________________________________________

#### R3: Permission Requirements

**Question**: What are the exact permission requirements for activation on each platform?

**Research Method**:

1. Test darwin activation with and without sudo
1. Test nixos activation with and without sudo
1. Document which operations require elevated permissions
1. Identify if permission requirements vary by activation command (switch vs boot)

**Decision Criteria**:

- Clear documentation of when sudo is required
- Justfile recipes must handle permissions transparently

**Expected Outcome**: Permission requirements matrix (platform × command → sudo needed?)

______________________________________________________________________

#### R4: Build Output Structure Stability

**Question**: Are activation script locations stable across nix/nix-darwin/nixos versions?

**Research Method**:

1. Review nix-darwin and nixos documentation for activation script contracts
1. Check git history for changes to activation script locations
1. Identify if script locations are part of stable API
1. Document any version-specific considerations

**Decision Criteria**:

- Script locations must be stable or have documented migration path
- Breaking changes must be rare and well-communicated

**Expected Outcome**: Confidence assessment for relying on activation script locations

______________________________________________________________________

#### R5: Platform Delegation Feasibility

**Question**: Can platform-specific flake inputs/outputs be delegated to platform library files instead of being centrally defined in flake.nix?

**Research Method**:

1. Examine current flake.nix structure - identify platform-specific code
1. Research Nix flake dynamic import capabilities (builtins.readDir, import expressions)
1. Investigate if flake inputs can be conditionally loaded based on filesystem
1. Test prototype: Create example platform library file that exports configuration
1. Measure performance impact of dynamic discovery vs static definitions
1. Search Nix community for similar patterns (NixOS/nix-darwin projects, flake-utils)
1. Assess impact on flake.lock and dependency management

**Decision Criteria**:

- Can reduce central flake.nix platform-specific code by ≥80%
- No measurable performance degradation (within 5% of current)
- Simpler to add new platforms than current approach
- Aligns with Nix community best practices

**Expected Outcome**: Feasibility assessment with recommendation (implement, defer, or reject)

**Possible Approaches to Test**:

1. **Function-based delegation**: Platform lib exports function that takes inputs, returns outputs
1. **Import-based delegation**: flake.nix imports platform lib and merges outputs
1. **Flake-based delegation**: Each platform has its own flake, main flake composes them
1. **Discovery-based delegation**: Scan platform/ directory and auto-load standard files

______________________________________________________________________

## Phase 1: Design & Contracts

### Data Model

See [data-model.md](./data-model.md) for complete entity definitions.

**Key Entities**:

- **Platform Configuration**: Identifies build output path pattern for a platform
- **Build Result**: Symlink to nix store containing configuration and activation script
- **Activation Script**: Executable that applies configuration to running system
- **Justfile Recipe**: Command interface wrapping build and activation operations

### API Contracts

See [contracts/justfile-api.md](./contracts/justfile-api.md) for complete specifications.

**Modified Recipes**:

- `_flake-output-path` - Returns flake output path for platform configuration
- `_rebuild-command` - Executes build or activation using nix build + activation script
- `build` - Builds configuration without activating
- `install` - Builds and activates configuration

### Integration Points

1. **Justfile → Nix Build**: Execute `nix build` with platform-specific flake output path
1. **Justfile → Activation Script**: Execute activation script from build result
1. **Platform Detection**: Use existing platform validation to determine activation script location
1. **Error Propagation**: Exit codes from activation scripts bubble up to justfile recipes

### Quick Start

See [quickstart.md](./quickstart.md) for complete usage examples and migration guide.

______________________________________________________________________

## Phase 2: Implementation Tasks

**Note**: Detailed task breakdown will be generated by `/speckit.tasks` command after Phase 1 completion.

### High-Level Task Groups

1. **Setup & Research** (Phase 0 completion)

   - Verify activation script locations on darwin
   - Document error handling patterns
   - Test permission requirements

1. **Core Implementation**

   - Modify `_rebuild-command` to detect activation script location
   - Update `_rebuild-command` to execute activation scripts instead of external tools
   - Add error handling for missing activation scripts
   - Handle sudo requirements based on platform

1. **Validation & Testing**

   - Test build command on darwin
   - Test install command on darwin
   - Verify error messages are clear
   - Test with intentionally broken configuration
   - Verify backward compatibility

1. **Documentation**

   - Update user-facing documentation in `docs/features/`
   - Document new workflow in quickstart.md
   - Add troubleshooting guide for common errors

______________________________________________________________________

## Post-Implementation Validation

### Success Criteria Validation

- [ ] SC-001: Build operations use identical commands across platforms (test on darwin)
- [ ] SC-002: Install operations use identical commands across platforms (test on darwin)
- [ ] SC-003: Adding new platform requires changes in only `_flake-output-path`
- [ ] SC-004: All existing workflows function without user-visible changes
- [ ] SC-005: Build and activation are cleanly separated (`just build` doesn't activate)
- [ ] SC-006: Error messages clearly indicate build vs activation failures
- [ ] SC-007: Build time within 10% of baseline (measure and compare)

### Constitution Re-Check

After implementation, verify:

- No platform-specific logic leaked into shared code
- All changes documented
- Backward compatibility maintained
- Cross-platform compatibility improved (Core Principle VI)

______________________________________________________________________

## Notes

### Technical Approach

The implementation leverages the fact that nix build outputs contain their own activation scripts. Instead of calling external tools like `darwin-rebuild switch`, we:

1. Build using platform-agnostic `nix build .#<output-path>`
1. Locate activation script in `result/` symlink
1. Execute activation script directly (e.g., `result/sw/bin/darwin-rebuild switch`)

This approach:

- Eliminates dependency on external tools being in PATH
- Works uniformly across platforms
- Simplifies adding new platforms (only flake output path changes)
- Maintains clean separation between build and activation

### Migration Strategy

No breaking changes. The updated `_rebuild-command` will:

1. Still accept same parameters (platform, command_type, user, profile)
1. Still support same command types (build, switch, boot, etc.)
1. Produce same end result (built and activated configuration)

Users will not notice any difference in command behavior, only improved consistency.

### Future Extensibility

Adding a new platform (e.g., kali, arch) will require:

1. Add platform configuration to flake.nix
1. Add one case to `_flake-output-path` helper
1. Document activation script location for that platform

No changes to `_rebuild-command`, `build`, or `install` recipes required.
